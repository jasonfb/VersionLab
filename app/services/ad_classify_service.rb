class AdClassifyService
  CTA_PATTERNS = /\b(shop\s+now|buy\s+now|learn\s+more|click\s+here|sign\s+up|get\s+started|subscribe|order\s+now|book\s+now|try\s+free|start\s+free|download|join\s+now|apply\s+now|contact\s+us|see\s+more|view\s+more|explore|discover|get\s+offer|claim|redeem|save\s+now|add\s+to\s+cart)\b/i

  MAX_CTA_WORDS = 5

  def initialize(ad)
    @ad = ad
  end

  def call
    layers = @ad.parsed_layers
    return [] if layers.blank?

    text_layers = layers.select { |l| l["type"] == "text" && l["content"].present? }
    shape_layers = layers.select { |l| l["type"] == "shape" }
    non_text_layers = layers.select { |l| l["type"] != "text" && l["type"] != "shape" || (l["type"] == "text" && l["content"].blank?) }

    classified_text = classify_text_layers(text_layers)
    attach_cta_backgrounds(classified_text, shape_layers)
    detect_wordmarks!(classified_text)

    classified = classified_text + classify_non_text_layers(non_text_layers)
    link_continuations!(classified)

    @ad.update!(classified_layers: classified)
    classified
  end

  private

  def classify_text_layers(layers)
    return [] if layers.empty?

    sorted_by_size = layers.sort_by { |l| -(l["font_size"].to_f) }

    classified = layers.map { |l| l.dup }
    assigned_roles = {}

    # Pass 1: CTA detection — short text with action words
    classified.each do |layer|
      content = layer["content"].to_s.strip
      word_count = content.split(/\s+/).size

      if word_count <= MAX_CTA_WORDS && content.match?(CTA_PATTERNS)
        layer["role"] = "cta"
        layer["confidence"] = 0.9
        assigned_roles[layer["id"]] = true
      end
    end

    # Pass 2: Background detection — full-canvas elements
    if @ad.width.present? && @ad.height.present?
      canvas_area = @ad.width * @ad.height

      classified.each do |layer|
        next if assigned_roles[layer["id"]]
        next unless layer["width"].present? && layer["height"].present?

        layer_area = layer["width"].to_f * layer["height"].to_f
        if layer_area >= canvas_area * 0.8
          layer["role"] = "background"
          layer["confidence"] = 0.8
          assigned_roles[layer["id"]] = true
        end
      end
    end

    # Pass 3: Rank remaining text by font size → headline, subhead, body
    unassigned = sorted_by_size.select { |l| !assigned_roles[l["id"]] }
    remaining_ids = unassigned.map { |l| l["id"] }

    remaining_ids.each_with_index do |id, index|
      layer = classified.find { |l| l["id"] == id }
      next unless layer

      if index == 0
        layer["role"] = "headline"
        layer["confidence"] = unassigned.size == 1 ? 0.7 : 0.85
      elsif index == 1
        layer["role"] = "subhead"
        layer["confidence"] = 0.7
      else
        layer["role"] = "body"
        layer["confidence"] = 0.6
      end
    end

    classified
  end

  # Detect multi-line text fragments that should be treated as one logical
  # element for AI re-flow. Adjacent text layers are linked into a chain when
  # they share font styling, are vertically stacked at the same x, and the
  # previous fragment doesn't end in a sentence terminator. Mutates `layers`
  # in place by setting `continuation_of` on chain children.
  CONTINUATION_TERMINATORS = /[.!?:]["'\)\]]?\s*$/
  CONTINUATION_ROLES = %w[body subhead].freeze

  def link_continuations!(layers)
    text_layers = layers.select { |l| l["type"] == "text" && l["content"].to_s.strip.present? }
    return if text_layers.size < 2

    # Process in document order (as parsed)
    text_layers.each_cons(2) do |prev, curr|
      next unless continuation?(prev, curr)
      curr["continuation_of"] = prev["id"]
      # Inherit role from the chain head so the UI/render treats them as one
      curr["role"] = prev["role"] if prev["role"]
    end
  end

  def continuation?(prev, curr)
    return false unless CONTINUATION_ROLES.include?(prev["role"]) && CONTINUATION_ROLES.include?(curr["role"])

    prev_text = prev["content"].to_s.strip
    return false if prev_text.match?(CONTINUATION_TERMINATORS)

    # Same font styling
    prev_size = prev["font_size"].to_f
    curr_size = curr["font_size"].to_f
    return false unless prev_size > 0 && curr_size > 0
    return false if (prev_size - curr_size).abs > 0.5
    return false if prev["font_family"].to_s != curr["font_family"].to_s
    return false if prev["fill"].to_s != curr["fill"].to_s

    # Roughly aligned horizontally (within 5% of canvas width, or 20px if no canvas)
    canvas_w = @ad.width.to_f
    x_tolerance = canvas_w > 0 ? canvas_w * 0.05 : 20.0
    return false if (prev["x"].to_f - curr["x"].to_f).abs > x_tolerance

    # Vertically stacked: curr starts within ~1.8x font size below prev's baseline
    vertical_gap = curr["y"].to_f - prev["y"].to_f
    return false unless vertical_gap > 0
    return false if vertical_gap > prev_size * 2.5

    true
  end

  # For each layer classified as a CTA, find the smallest shape whose
  # bounding box contains the CTA's anchor point. If found, capture the
  # shape's fill and corner radius (as a ratio of its height) so the
  # SvgComposer can render a proportional button background in resizes.
  def attach_cta_backgrounds(classified_text, shape_layers)
    return if shape_layers.empty?

    classified_text.each do |layer|
      next unless layer["role"] == "cta"
      cx = layer["x"].to_f
      cy = layer["y"].to_f

      candidates = shape_layers.select do |s|
        sx = s["x"].to_f
        sy = s["y"].to_f
        sw = s["width"].to_f
        sh = s["height"].to_f
        cx >= sx && cx <= sx + sw && cy >= sy - sh && cy <= sy + sh
      end
      next if candidates.empty?

      best = candidates.min_by { |s| s["width"].to_f * s["height"].to_f }
      h = best["height"].to_f
      w = best["width"].to_f
      rx = best["rx"].to_f
      # If the original shape is a rect with no rx, treat as square corners (0).
      # Path-based shapes get a default 15% rounding since we can't read corners.
      rx_ratio = if best["shape"] == "path"
        0.5
      else
        h > 0 ? (rx / h) : 0.0
      end

      layer["cta_background_color"] = best["fill"]
      layer["cta_background_rx_ratio"] = rx_ratio
      # Capture original shape aspect for centering hints (optional, unused for now)
      layer["cta_background_aspect"] = (h > 0 && w > 0) ? (w / h) : nil
    end
  end

  # Heuristic wordmark detection. A wordmark is a text element (or small
  # group of stacked elements with possibly different fonts/sizes) that lives
  # like a brand mark in the upper portion of the ad. Detection is purely
  # spatial — we do NOT require members to share font family or size.
  #
  # Pre-selects wordmarks during classification; user can confirm/override
  # in the classify UI. Members of a group share `wordmark_group_id` (the
  # head member's id).
  def detect_wordmarks!(classified)
    return unless @ad.width.present? && @ad.height.present?

    # Candidates: short text in the top 30% of the canvas, not already
    # locked into a high-confidence role like CTA or background.
    top_band_y = @ad.height * 0.30
    candidates = classified.select do |l|
      next false unless l["type"] == "text" && l["content"].present?
      next false if %w[cta background].include?(l["role"])
      next false if l["y"].to_f > top_band_y
      word_count = l["content"].to_s.split(/\s+/).size
      word_count <= 3
    end
    return if candidates.empty?

    # Cluster by spatial proximity. Two candidates join the same cluster if
    # they're within ~2x the larger font size vertically and overlap or are
    # close horizontally (within 1x font size).
    sorted = candidates.sort_by { |l| [l["y"].to_f, l["x"].to_f] }
    clusters = []
    sorted.each do |layer|
      placed = false
      clusters.each do |cluster|
        if cluster.any? { |c| wordmark_adjacent?(c, layer) }
          cluster << layer
          placed = true
          break
        end
      end
      clusters << [layer] unless placed
    end

    # Only mark as wordmark if the cluster has 2+ members (the joining is
    # the whole point of the feature). Single-element top-corner brand text
    # stays as headline/subhead unless the user reclassifies manually.
    clusters.each do |cluster|
      next if cluster.size < 2
      head_id = cluster.first["id"]
      cluster.each do |member|
        member["role"] = "wordmark"
        member["confidence"] = 0.75
        member["wordmark_group_id"] = head_id
      end
    end
  end

  def wordmark_adjacent?(a, b)
    ax = a["x"].to_f
    ay = a["y"].to_f
    bx = b["x"].to_f
    by = b["y"].to_f
    a_size = [a["font_size"].to_f, 8.0].max
    b_size = [b["font_size"].to_f, 8.0].max
    max_size = [a_size, b_size].max

    vertical_gap = (ay - by).abs
    horizontal_gap = (ax - bx).abs

    vertical_gap <= max_size * 2.5 && horizontal_gap <= max_size * 4.0
  end

  def classify_non_text_layers(layers)
    layers.map do |layer|
      classified = layer.dup
      if layer["type"] == "image"
        classified["role"] = "logo"
        classified["confidence"] = 0.8
      else
        classified["role"] = "decoration"
        classified["confidence"] = 0.5
      end
      classified
    end
  end
end
