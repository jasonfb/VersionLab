# frozen_string_literal: true

module AdLayout
  class SvgComposer
    def initialize(ad)
      @ad = ad
    end

    # Build a new SVG from scratch at target dimensions using computed layout.
    # Optional +layer_overrides+ hash (keyed by layer ID) applies user edits:
    #   x_offset/y_offset, rect_x/rect_y, box_width/box_height, font_size, deleted
    def compose(layout_result, layer_overrides: {})
      width = layout_result.target_width
      height = layout_result.target_height
      overrides = layer_overrides || {}

      builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.svg(
          xmlns: "http://www.w3.org/2000/svg",
          width: width,
          height: height,
          viewBox: "0 0 #{width} #{height}"
        ) do
          # Embed web fonts used by text layers
          render_font_imports(xml, layout_result.layers)

          # Background
          render_background(xml, width, height)

          # Text and other elements
          layout_result.layers.each do |layer|
            next if layer["excluded"]
            ov = overrides[layer["id"]]&.stringify_keys || {}
            next if ov["deleted"]

            merged = apply_layer_overrides(layer, ov)

            if merged["type"] == "image"
              render_image_layer(xml, merged)
            elsif merged["type"] == "text" && merged["content"].present?
              render_cta_background(xml, merged) if merged["cta_background_color"].present?
              render_text_layer(xml, merged)
            end
          end
        end
      end

      builder.to_xml
    end

    private

    # Extract unique Google-importable font families from layers and embed @import rules
    def render_font_imports(xml, layers)
      families = layers
        .select { |l| l["type"] == "text" && l["font_family"].present? }
        .map { |l| l["font_family"].split(",").first.strip.gsub(/['"]/, "") }
        .uniq
        .reject { |f| f.match?(/\b(sans-serif|serif|monospace|cursive|fantasy)\b/i) }

      return if families.empty?

      imports = families.map { |f|
        encoded = f.gsub(" ", "+")
        "@import url('https://fonts.googleapis.com/css2?family=#{encoded}:wght@100;200;300;400;500;600;700;800;900&display=swap');"
      }.join("\n")

      xml.style(type: "text/css") do
        xml.text(imports)
      end
    end

    def render_background(xml, width, height)
      bg_color = @ad.background_color.presence || "#000000"
      xml.rect(width: width, height: height, fill: bg_color)

      # If the user classified an image layer as the background, keep it as a
      # placeholder background in the resize. Cover-fit (slice) so a small
      # source image scales up to fill the entire target — it may be replaced
      # later in the styling step, but this avoids a black void.
      bg_layer = background_image_layer
      return unless bg_layer && bg_layer["href"].present?

      xml.image(
        href: bg_layer["href"],
        x: 0,
        y: 0,
        width: width,
        height: height,
        preserveAspectRatio: "xMidYMid slice"
      )
    end

    def background_image_layer
      layers = @ad.classified_layers
      return nil unless layers.present?
      layers.find { |l| l["role"] == "background" && l["type"] == "image" }
    end

    # Draw a rounded-rect button background behind a CTA text layer using the
    # color and corner radius captured from the original ad shape.
    def render_cta_background(xml, layer)
      x = layer["x"].to_f.round
      y = layer["y"].to_f.round
      w = layer["width"].to_f.round
      h = layer["height"].to_f.round
      return if w <= 0 || h <= 0

      rx_ratio = layer["cta_background_rx_ratio"].to_f
      rx = (h * rx_ratio).round
      rx = (h / 2.0).round if rx > h / 2.0

      attrs = {
        x: x,
        y: y,
        width: w,
        height: h,
        fill: layer["cta_background_color"]
      }
      attrs[:rx] = rx if rx > 0
      attrs[:ry] = rx if rx > 0
      xml.rect(attrs)
    end

    def render_image_layer(xml, layer)
      xml.image(
        href: layer["href"],
        x: layer["x"].to_f.round,
        y: layer["y"].to_f.round,
        width: layer["width"].to_f.round,
        height: layer["height"].to_f.round
      )
    end

    def render_text_layer(xml, layer)
      x = layer["x"].to_f
      y = layer["y"].to_f
      font_size = layer["font_size"].to_f
      font_family = layer["font_family"].presence || "sans-serif"
      align = layer["align"] || "left"
      region_width = layer["width"].to_f
      # If content was overridden, re-wrap; otherwise use pre-wrapped lines
      lines = if layer["content_overridden"]
        wrap_text(layer["content"], region_width, font_size)
      else
        layer["wrapped_lines"] || [layer["content"]]
      end

      # Compute text-anchor and x position based on alignment
      text_anchor, text_x = compute_alignment(align, x, region_width)

      # Determine fill color — try to read from original layer or use white as default
      fill = layer["fill"].presence || layer["color"].presence || "#FFFFFF"

      # Vertical centering: place first line baseline at y + font_size,
      # then offset subsequent lines by line_height
      line_height = font_size * 1.3
      start_y = y + font_size

      # When the CTA has a button background, vertically center the text
      # block inside the button rect rather than top-aligning it.
      if layer["cta_background_color"].present?
        region_h = layer["height"].to_f
        line_count = lines.size
        block_h = font_size + (line_count - 1) * line_height
        start_y = y + ((region_h - block_h) / 2.0) + font_size
      end

      font_weight = layer["font_weight"].presence || "normal"

      xml.text_(
        x: text_x.round,
        y: start_y.round,
        fill: fill,
        "font-size": font_size.round(1),
        "font-family": font_family,
        "font-weight": font_weight,
        "text-anchor": text_anchor
      ) do
        lines.each_with_index do |line, i|
          if i == 0
            xml.tspan(line)
          else
            xml.tspan(line, x: text_x.round, dy: line_height.round)
          end
        end
      end
    end

    # Merge user overrides into a layer hash. Handles both position offsets
    # (x_offset/y_offset) and absolute repositioning (rect_x/rect_y + box_width/box_height).
    def apply_layer_overrides(layer, ov)
      return layer if ov.blank?

      merged = layer.dup

      if ov["rect_x"].present? && ov["rect_y"].present? && ov["box_width"].present? && ov["box_height"].present?
        # Absolute reposition from resize — use rect position directly
        merged["x"] = ov["rect_x"].to_f.round.to_s
        merged["y"] = ov["rect_y"].to_f.round.to_s
        merged["width"] = ov["box_width"].to_f.round.to_s
        merged["height"] = ov["box_height"].to_f.round.to_s
      else
        # Relative offset from drag
        merged["x"] = (layer["x"].to_f + (ov["x_offset"] || 0).to_f).round.to_s
        merged["y"] = (layer["y"].to_f + (ov["y_offset"] || 0).to_f).round.to_s
      end

      merged["font_size"] = ov["font_size"].to_f if ov["font_size"].present?
      merged["fill"] = ov["fill"] if ov["fill"].present?
      merged["color"] = ov["fill"] if ov["fill"].present?
      merged["font_family"] = ov["font_family"] if ov["font_family"].present?
      merged["font_weight"] = ov["is_bold"] ? "bold" : "normal" if ov.key?("is_bold")
      if ov["content"].present?
        merged["content"] = ov["content"]
        merged["content_overridden"] = true
      end
      merged["align"] = ov["text_align"] if ov["text_align"].present?

      merged
    end

    # Simple word wrap using estimated character width (matches frontend logic)
    def wrap_text(content, region_width, font_size)
      return [content] if content.blank? || region_width <= 0 || font_size <= 0
      char_width = font_size * 0.52
      chars_per_line = [1, (region_width / char_width).floor].max
      words = content.split(/\s+/)
      lines = []
      current = []
      current_len = 0
      words.each do |word|
        if current.empty? || current_len + 1 + word.length <= chars_per_line
          current << word
          current_len += (current.length == 1 ? 0 : 1) + word.length
        else
          lines << current.join(" ")
          current = [word]
          current_len = word.length
        end
      end
      lines << current.join(" ") if current.any?
      lines
    end

    def compute_alignment(align, region_x, region_width)
      case align
      when "center"
        ["middle", region_x + region_width / 2.0]
      when "right"
        ["end", region_x + region_width]
      else
        ["start", region_x]
      end
    end
  end
end
