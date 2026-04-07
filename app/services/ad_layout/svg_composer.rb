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
