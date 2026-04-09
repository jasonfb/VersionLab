require "set"

module AdLayout
  class LayoutEngine
    Result = Data.define(:layers, :bucket, :target_width, :target_height)

    def initialize(ad)
      @ad = ad
    end

    # Compute layout for target dimensions. Returns a Result with positioned layers.
    # Falls back to legacy proportional scaling if classifications aren't confirmed.
    def compute_layout(target_width, target_height)
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

      # Wordmark groups: lay out as a single unit (like an image) so members
      # keep their relative spacing. Process before per-layer iteration and
      # skip the members in the main loop.
      wordmark_template = template[:wordmark]
      wordmark_member_ids = Set.new
      if placed_roles.include?("wordmark") && wordmark_template && !wordmark_template[:drop]
        wordmark_groups = classified
          .select { |l| l["role"] == "wordmark" && l["wordmark_group_id"].present? }
          .group_by { |l| l["wordmark_group_id"] }

        wordmark_groups.each do |_group_id, members|
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
        next if role == "wordmark" # ungrouped wordmarks fall through silently
        next unless placed_roles.include?(role)

        role_template = template[role.to_sym]
        next unless role_template && !role_template[:drop]

        anchor_px = LayoutTemplate.anchor_to_pixels(
          role_template[:anchor], target_width, target_height
        )

        positioned_layer = position_layer(
          layer, role_template, anchor_px, base_scale, font_lookup
        )
        positioned << positioned_layer
      end

      Result.new(
        layers: positioned,
        bucket: bucket,
        target_width: target_width,
        target_height: target_height
      )
    end

    private

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
