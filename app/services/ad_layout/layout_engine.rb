require "set"

module AdLayout
  class LayoutEngine
    Result = Data.define(:layers, :bucket, :target_width, :target_height)

    def initialize(ad)
      @ad = ad
    end

    # Compute layout for target dimensions. Returns a Result with positioned layers.
    # Falls back to legacy proportional scaling if classifications aren't confirmed.
    #
    # layout_variant: "left", "center", or "right" — overrides the per-role text
    # alignment from the template so the designer can pick a starting layout.
    def compute_layout(target_width, target_height, layout_variant: "center")
      unless @ad.classifications_confirmed? && @ad.classified_layers.present?
        return legacy_layout(target_width, target_height)
      end

      bucket = AspectRatioBucket.classify(target_width, target_height)
      template = LayoutTemplate.for_bucket(bucket)
      placed_roles = LayoutTemplate.placed_roles(bucket)

      base_scale = compute_base_font_scale(target_width, target_height)
      font_lookup = build_font_lookup

      positioned = []

      # Collapse continuation chains so multi-fragment sentences are positioned
      # as a single text block per chain head.
      classified = AdContinuation.collapse(@ad.classified_layers)

      # Join groups: lay out as a single unit (like an image) so members
      # keep their relative spacing. A layer joins a group by having
      # wordmark_group_id set to the head layer's id. Process before the
      # per-layer iteration and skip all group members in the main loop.
      wordmark_template = template[:wordmark]
      wordmark_member_ids = Set.new
      if wordmark_template && !wordmark_template[:drop]
        # Collect layers that explicitly reference a group head
        explicit_by_gid = classified
          .select { |l| l["wordmark_group_id"].present? }
          .group_by { |l| l["wordmark_group_id"] }

        join_groups = explicit_by_gid.filter_map do |gid, explicit_members|
          head = classified.find { |l| l["id"] == gid }
          all = ([head] + explicit_members).compact.uniq { |l| l["id"] }
          [gid, all] if all.size >= 2
        end.to_h

        join_groups.each do |_group_id, members|
          anchor_px = LayoutTemplate.anchor_to_pixels(
            wordmark_template[:anchor], target_width, target_height
          )
          positioned_members = position_wordmark_group(members, anchor_px)
          positioned.concat(positioned_members)
          members.each { |m| wordmark_member_ids << m["id"] }
        end
      end

      classified.each do |layer|
        next if wordmark_member_ids.include?(layer["id"])
        role = layer["role"]
        next unless role
        next unless placed_roles.include?(role)

        role_template = template[role.to_sym]
        next unless role_template && !role_template[:drop]

        # Apply layout variant alignment override for text roles
        effective_template = apply_variant_alignment(role_template, role, layout_variant)

        anchor_px = LayoutTemplate.anchor_to_pixels(
          effective_template[:anchor], target_width, target_height
        )

        positioned_layer = position_layer(
          layer, effective_template, anchor_px, base_scale, font_lookup
        )
        positioned << positioned_layer
      end

      positioned = resolve_overlaps(positioned, target_width, target_height)

      Result.new(
        layers: positioned,
        bucket: bucket,
        target_width: target_width,
        target_height: target_height
      )
    end

    private

    # Roles whose alignment the layout variant can override. Wordmark and
    # decoration keep their template-defined alignment regardless of variant.
    VARIANT_ALIGNABLE_ROLES = %w[headline subhead body cta logo].to_set.freeze

    # Override a role_template's align (and optionally anchor x-position) based
    # on the chosen layout variant. Returns the original template if no override
    # applies (e.g. for wordmark, decoration, or "center" variant which matches
    # most templates already).
    def apply_variant_alignment(role_template, role, layout_variant)
      return role_template unless VARIANT_ALIGNABLE_ROLES.include?(role)
      return role_template if layout_variant.nil?

      target_align = layout_variant # "left", "center", or "right"
      return role_template if role_template[:align] == target_align &&
        target_align != "center" # always re-center for "center" variant

      # Shallow-dup so we don't mutate the frozen template
      overridden = role_template.dup
      overridden[:align] = target_align

      anchor = role_template[:anchor]
      margin = 0.05
      case target_align
      when "left"
        overridden[:anchor] = anchor.merge(x: margin)
      when "center"
        # Center the anchor region horizontally on the canvas
        new_x = (1.0 - anchor[:w]) / 2.0
        overridden[:anchor] = anchor.merge(x: new_x)
      when "right"
        # Push region rightward so its right edge sits at (1.0 - margin)
        new_x = 1.0 - margin - anchor[:w]
        new_x = margin if new_x < margin
        overridden[:anchor] = anchor.merge(x: new_x)
      end

      overridden
    end

    GAP = 6 # pixels of breathing room between elements after overlap resolution

    # Resolve overlapping elements by pushing them downward. Processes elements
    # top-to-bottom: for each element, if it overlaps any already-finalized
    # element, shift it below the bottom of the overlapper. This naturally
    # handles cascading overlaps since top elements are finalized first.
    def resolve_overlaps(positioned, canvas_width, canvas_height)
      return positioned if positioned.size < 2

      # Skip background-role layers — they're full-canvas and shouldn't participate
      elements = positioned.reject { |l| l["role"] == "background" || l["role"] == "decoration" }
      passthrough = positioned.select { |l| l["role"] == "background" || l["role"] == "decoration" }
      return positioned if elements.size < 2

      # Sort by y-position (top to bottom)
      elements.sort_by! { |l| l["y"].to_f }

      # Compute actual bounding boxes
      bboxes = elements.map { |l| actual_bbox(l) }

      # Greedy top-to-bottom resolution
      elements.each_with_index do |layer, i|
        bbox = bboxes[i]
        # Check against all previously finalized elements
        (0...i).each do |j|
          other = bboxes[j]
          if rects_overlap?(bbox, other)
            shift = other[:y] + other[:h] + GAP - bbox[:y]
            if shift > 0
              bbox[:y] += shift
              layer["y"] = bbox[:y].round.to_s
            end
          end
        end

        # Clamp to canvas bottom — don't let elements fall off
        if bbox[:y] + bbox[:h] > canvas_height
          layer["y"] = [canvas_height - bbox[:h], 0].max.round.to_s
          bbox[:y] = layer["y"].to_f
        end
      end

      passthrough + elements
    end

    # Compute the actual rendered bounding box for a positioned layer.
    # For text, this uses wrapped_lines and font_size to get the real height
    # rather than the anchor region height.
    def actual_bbox(layer)
      x = layer["x"].to_f
      y = layer["y"].to_f
      w = layer["width"].to_f

      if layer["type"] == "text"
        font_size = layer["font_size"].to_f
        lines = layer["wrapped_lines"] || [layer["content"]]
        line_count = [lines.size, 1].max
        line_height = font_size * 1.3
        h = font_size + (line_count - 1) * line_height
      else
        h = layer["height"].to_f
      end

      { x: x, y: y, w: w, h: h }
    end

    def rects_overlap?(a, b)
      a[:x] < b[:x] + b[:w] &&
        a[:x] + a[:w] > b[:x] &&
        a[:y] < b[:y] + b[:h] &&
        a[:y] + a[:h] > b[:y]
    end

    # Position a wordmark group as a single unit. Members may have different
    # font sizes/families — we treat the group's combined bounding box like
    # an image: scale it to fit the wordmark anchor preserving aspect ratio,
    # then place each member at its scaled relative position with a scaled
    # font size. No text wrapping; wordmarks are short by design.
    def position_wordmark_group(members, anchor_px)
      return [] if members.empty?

      # Per-member original bbox (estimated from font_size + content length)
      bboxes = members.map do |layer|
        font_size = layer["font_size"].to_f
        font_size = 12.0 if font_size <= 0
        content = layer["content"].to_s
        # Approximate width using the same heuristic used elsewhere in this file
        est_width = layer["width"].to_f
        est_width = font_size * content.length * 0.55 if est_width <= 0
        est_height = layer["height"].to_f
        est_height = font_size * 1.3 if est_height <= 0
        {
          layer: layer,
          font_size: font_size,
          x: layer["x"].to_f,
          y: layer["y"].to_f,
          w: est_width,
          h: est_height
        }
      end

      group_min_x = bboxes.map { |b| b[:x] }.min
      group_min_y = bboxes.map { |b| b[:y] }.min
      group_max_x = bboxes.map { |b| b[:x] + b[:w] }.max
      group_max_y = bboxes.map { |b| b[:y] + b[:h] }.max
      group_w = group_max_x - group_min_x
      group_h = group_max_y - group_min_y
      return [] if group_w <= 0 || group_h <= 0

      scale = [anchor_px[:w] / group_w, anchor_px[:h] / group_h].min
      # Center the scaled group within the anchor region
      scaled_w = group_w * scale
      scaled_h = group_h * scale
      offset_x = anchor_px[:x] + (anchor_px[:w] - scaled_w) / 2.0
      offset_y = anchor_px[:y] + (anchor_px[:h] - scaled_h) / 2.0

      bboxes.map do |b|
        result = b[:layer].dup
        new_x = offset_x + (b[:x] - group_min_x) * scale
        new_y = offset_y + (b[:y] - group_min_y) * scale
        new_font = (b[:font_size] * scale).round(1)
        new_font = [new_font, 6.0].max # don't scale below readability floor

        result["x"] = new_x.round.to_s
        result["y"] = new_y.round.to_s
        result["width"] = (b[:w] * scale).round.to_s
        result["height"] = (b[:h] * scale).round.to_s
        result["font_size"] = new_font.to_s
        result["align"] = "left"
        result["wrapped_lines"] = [b[:layer]["content"]]
        # Strip any inherited cta_background since wordmarks aren't buttons
        result.delete("cta_background_color")
        result.delete("cta_background_rx_ratio")
        result
      end
    end

    def position_layer(layer, role_template, anchor_px, base_scale, font_lookup)
      result = layer.dup

      if layer["type"] == "image"
        # Image layers: position within anchor region, scale to fit while preserving aspect ratio
        result["x"] = anchor_px[:x].to_s
        result["y"] = anchor_px[:y].to_s
        orig_w = layer["width"].to_f
        orig_h = layer["height"].to_f
        if orig_w > 0 && orig_h > 0
          scale = [ anchor_px[:w].to_f / orig_w, anchor_px[:h].to_f / orig_h ].min
          result["width"] = (orig_w * scale).round.to_s
          result["height"] = (orig_h * scale).round.to_s
        else
          result["width"] = anchor_px[:w].to_s
          result["height"] = anchor_px[:h].to_s
        end
        return result
      elsif layer["type"] == "text"
        original_size = layer["font_size"].to_f
        # PDF-converted regions have no font_size — estimate from region height
        if original_size <= 0 && layer["height"].to_f > 0
          original_size = estimate_font_size(layer)
        end

        scaled_size = (original_size * base_scale * role_template[:font_scale]).round(1)
        scaled_size = [scaled_size, 8.0].max # minimum readable size

        result["font_size"] = scaled_size.to_s
        result["align"] = role_template[:align]

        # Word wrap using actual font metrics if available
        if layer["content"].present?
          max_width = anchor_px[:w]
          wrapped = wrap_text(layer["content"], layer["font_family"], scaled_size, max_width, font_lookup)
          result["wrapped_lines"] = wrapped
        end
      end

      result["x"] = anchor_px[:x].to_s
      result["y"] = anchor_px[:y].to_s
      result["width"] = anchor_px[:w].to_s
      result["height"] = anchor_px[:h].to_s

      result
    end

    def wrap_text(text, font_family, font_size, max_width, font_lookup)
      ad_font = find_font(font_family, font_lookup)

      if ad_font
        ad_font.word_wrap(text, font_size, max_width)
      else
        # Approximate: assume average character width is ~0.55 * font_size
        approx_char_width = font_size * 0.55
        chars_per_line = [(max_width / approx_char_width).floor, 1].max
        simple_wrap(text, chars_per_line)
      end
    end

    # Estimate font size for PDF-converted regions that lack font_size.
    # Uses region height and content length to approximate a reasonable size.
    def estimate_font_size(layer)
      height = layer["height"].to_f
      width = layer["width"].to_f
      content = layer["content"] || ""

      # Estimate line count from content length and region aspect ratio
      if width > 0 && content.length > 0
        # Approximate chars per line assuming average char width ~0.55 * font_size
        # and font_size ~= height / line_count
        # Start with single-line assumption and iterate once
        estimated_size = height * 0.75 # assume single line, cap-height ratio
        chars_per_line = [(width / (estimated_size * 0.55)).floor, 1].max
        line_count = [(content.length.to_f / chars_per_line).ceil, 1].max
        estimated_size = (height / (line_count * 1.3)) # 1.3 line-height
        [estimated_size, 12.0].max
      else
        [height * 0.75, 12.0].max
      end
    end

    def simple_wrap(text, chars_per_line)
      words = text.split(/\s+/)
      lines = []
      current = []
      current_len = 0

      words.each do |word|
        if current.empty? || (current_len + 1 + word.length) <= chars_per_line
          current << word
          current_len += (current.empty? ? 0 : 1) + word.length
        else
          lines << current.join(" ")
          current = [word]
          current_len = word.length
        end
      end
      lines << current.join(" ") if current.any?
      lines
    end

    def find_font(font_family, font_lookup)
      return nil unless font_family.present? && font_lookup.any?

      # Try exact match first, then partial match
      clean_name = font_family.to_s.gsub(/['"]/, "").strip
      font_lookup[clean_name] || font_lookup.find { |name, _| clean_name.include?(name) || name.include?(clean_name) }&.last
    end

    def build_font_lookup
      return {} unless @ad.ad_fonts.loaded? || @ad.ad_fonts.any?

      @ad.ad_fonts.each_with_object({}) do |font, hash|
        hash[font.font_name] = font
        hash[font.postscript_name] = font if font.postscript_name.present?
      end
    end

    def compute_base_font_scale(target_width, target_height)
      return 1.0 unless @ad.width.present? && @ad.height.present?

      scale_x = target_width.to_f / @ad.width
      scale_y = target_height.to_f / @ad.height
      [scale_x, scale_y].min
    end

    def legacy_layout(target_width, target_height)
      scale_x = target_width.to_f / @ad.width
      scale_y = target_height.to_f / @ad.height

      layers = (@ad.parsed_layers || []).map do |layer|
        resized = layer.dup
        resized["x"] = (layer["x"].to_f * scale_x).round.to_s if layer["x"]
        resized["y"] = (layer["y"].to_f * scale_y).round.to_s if layer["y"]
        resized["width"] = (layer["width"].to_f * scale_x).round.to_s if layer["width"]
        resized["height"] = (layer["height"].to_f * scale_y).round.to_s if layer["height"]

        if layer["font_size"].present?
          min_scale = [scale_x, scale_y].min
          resized["font_size"] = [layer["font_size"].to_f * min_scale, 8].max.round.to_s
        end

        resized
      end

      bucket = AspectRatioBucket.classify(target_width, target_height)
      Result.new(layers: layers, bucket: bucket, target_width: target_width, target_height: target_height)
    end
  end
end
