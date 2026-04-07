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
    non_text_layers = layers.select { |l| l["type"] != "text" || l["content"].blank? }

    classified = classify_text_layers(text_layers) + classify_non_text_layers(non_text_layers)

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
