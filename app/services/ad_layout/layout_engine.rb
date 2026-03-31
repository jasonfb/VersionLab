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

      @ad.classified_layers.each do |layer|
        role = layer["role"]
        next unless role
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

    def position_layer(layer, role_template, anchor_px, base_scale, font_lookup)
      result = layer.dup

      if layer["type"] == "text" && layer["font_size"].present?
        original_size = layer["font_size"].to_f
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
