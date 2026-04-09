module AdLayout
  class SvgComposer
    def initialize(ad)
      @ad = ad
    end

    # Build a new SVG from scratch at target dimensions using computed layout.
    def compose(layout_result)
      width = layout_result.target_width
      height = layout_result.target_height

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
            if layer["type"] == "image"
              render_image_layer(xml, layer)
            elsif layer["type"] == "text" && layer["content"].present?
              render_cta_background(xml, layer) if layer["cta_background_color"].present?
              render_text_layer(xml, layer)
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
      lines = layer["wrapped_lines"] || [layer["content"]]

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
        line_count = (layer["wrapped_lines"] || [layer["content"]]).size
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
