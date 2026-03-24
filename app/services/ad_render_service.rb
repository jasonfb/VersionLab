class AdRenderService
  class Error < StandardError; end

  def initialize(ad_version)
    @version = ad_version
    @ad = ad_version.ad
  end

  def call
    raise Error, "Ad has no dimensions" unless @ad.width.present? && @ad.height.present?

    svg = build_svg
    binary = rasterize(svg)
    attach_image(binary)
  end

  private

  def build_svg
    w = @ad.width.to_i
    h = @ad.height.to_i

    layers_xml = build_background(w, h) +
                 build_text_layers +
                 build_overlay(w, h) +
                 build_play_button(w, h)

    <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg xmlns="http://www.w3.org/2000/svg"
           xmlns:xlink="http://www.w3.org/1999/xlink"
           width="#{w}" height="#{h}" viewBox="0 0 #{w} #{h}">
        #{layers_xml}
      </svg>
    SVG
  end

  def build_background(w, h)
    if @ad.solid_color?
      color = @ad.background_color.presence || "#000000"
      %(<rect width="#{w}" height="#{h}" fill="#{escape(color)}" />)
    elsif @ad.image? && @ad.background_asset&.file&.attached?
      data_uri = asset_data_uri(@ad.background_asset)
      if data_uri
        %(<image href="#{data_uri}" x="0" y="0" width="#{w}" height="#{h}" preserveAspectRatio="xMidYMid slice" />)
      else
        %(<rect width="#{w}" height="#{h}" fill="#000000" />)
      end
    else
      %(<rect width="#{w}" height="#{h}" fill="#000000" />)
    end
  end

  def build_text_layers
    generated = generated_content_map
    return "" if generated.empty?

    parsed = @ad.parsed_layers || []
    overrides = @ad.layer_overrides || {}

    parsed.select { |l| l["type"] == "text" }.map { |layer|
      layer_id = layer["id"]
      content = generated[layer_id]
      next unless content.present?

      ov = (overrides[layer_id] || {}).with_indifferent_access
      x = (layer["x"].to_f + (ov[:x_offset] || 0).to_f).round
      y = (layer["y"].to_f + (ov[:y_offset] || 0).to_f).round
      w = layer["width"].to_f.round
      h = layer["height"].to_f.round

      build_text_element(x, y, w, h, content, ov)
    }.compact.join("\n")
  end

  def build_text_element(x, y, w, h, content, ov)
    font_family = ov[:font_family].presence || "Liberation Sans, Arial, sans-serif"
    font_size = (ov[:font_size].presence || auto_font_size(content, w, h)).to_f
    fill = ov[:fill].presence || "#FFFFFF"
    font_weight = ov[:is_bold] ? "bold" : "normal"
    font_style = ov[:is_italic] ? "italic" : "normal"
    text_decoration = ov[:is_underline] ? "underline" : "none"
    text_anchor = case ov[:text_align].to_s
                  when "center" then "middle"
                  when "right" then "end"
                  else "start"
                  end
    letter_spacing = ov[:letter_spacing].presence || "0"
    line_height = (ov[:line_height].presence || "1.3").to_f

    # Calculate text x position based on alignment
    text_x = case text_anchor
             when "middle" then x + (w > 0 ? w / 2 : 0)
             when "end" then x + (w > 0 ? w : 0)
             else x
             end

    # Word-wrap into lines that fit within the region width
    lines = if w > 0
              wrap_text(content, font_size, w, font_weight == "bold")
            else
              [ content ]
            end

    line_spacing = font_size * line_height
    # Start at y + font_size to account for SVG text baseline
    start_y = y + font_size

    tspans = lines.map.with_index { |line, i|
      ty = (start_y + i * line_spacing).round
      %(<tspan x="#{text_x}" y="#{ty}">#{escape(line)}</tspan>)
    }.join

    attrs = [
      %(font-family="#{escape(font_family)}"),
      %(font-size="#{font_size}"),
      %(fill="#{escape(fill)}"),
      %(font-weight="#{font_weight}"),
      %(font-style="#{font_style}"),
      %(text-anchor="#{text_anchor}"),
      %(letter-spacing="#{escape(letter_spacing)}"),
      %(text-decoration="#{text_decoration}")
    ].join(" ")

    %(<text #{attrs}>#{tspans}</text>)
  end

  # Auto-scale font size to fill the region. Estimates how many lines the text
  # will occupy and picks a size so the text block fits the region height.
  def auto_font_size(content, region_width, region_height)
    return 24 if region_width <= 0 || region_height <= 0

    word_count = content.split.size
    char_count = content.length
    return 24 if char_count == 0

    # Try sizes from large to small, pick the largest that fits
    (120).downto(12).each do |size|
      char_width = size * 0.6
      chars_per_line = [ (region_width / char_width).floor, 1 ].max
      line_count = (char_count.to_f / chars_per_line).ceil
      total_height = line_count * size * 1.3
      return size if total_height <= region_height
    end

    12 # minimum
  end

  # Simple word-wrap: estimate characters per line from font size and region width
  def wrap_text(text, font_size, region_width, bold = false)
    # Approximate average character width as 0.6 * font_size (0.65 for bold)
    char_width = font_size * (bold ? 0.65 : 0.6)
    chars_per_line = [ (region_width / char_width).floor, 1 ].max

    words = text.split(/\s+/)
    lines = []
    current = ""

    words.each do |word|
      candidate = current.empty? ? word : "#{current} #{word}"
      if candidate.length > chars_per_line && !current.empty?
        lines << current
        current = word
      else
        current = candidate
      end
    end
    lines << current unless current.empty?
    lines.empty? ? [ text ] : lines
  end

  def build_overlay(w, h)
    return "" unless @ad.overlay_enabled?

    opacity = (@ad.overlay_opacity || 80).to_f / 100.0
    color = @ad.overlay_color.presence || "#FFFFFF"

    if @ad.gradient?
      <<~XML
        <defs>
          <linearGradient id="overlay-grad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#{escape(color)}" stop-opacity="0" />
            <stop offset="100%" stop-color="#{escape(color)}" stop-opacity="#{opacity}" />
          </linearGradient>
        </defs>
        <rect width="#{w}" height="#{h}" fill="url(#overlay-grad)" />
      XML
    else
      %(<rect width="#{w}" height="#{h}" fill="#{escape(color)}" fill-opacity="#{opacity}" />)
    end
  end

  def build_play_button(w, h)
    return "" unless @ad.play_button_enabled?

    color = @ad.play_button_color.presence || "#FFFFFF"
    cx = w / 2
    cy = h / 2
    size = [ w, h ].min * 0.08

    # Circle + triangle
    <<~XML
      <circle cx="#{cx}" cy="#{cy}" r="#{size}" fill="rgba(0,0,0,0.5)" />
      <polygon points="#{cx - size * 0.35},#{cy - size * 0.5} #{cx - size * 0.35},#{cy + size * 0.5} #{cx + size * 0.5},#{cy}" fill="#{escape(color)}" />
    XML
  end

  def generated_content_map
    (@version.generated_layers || []).each_with_object({}) do |layer, h|
      h[layer["id"]] = layer["content"]
    end
  end

  def asset_data_uri(asset)
    blob = asset.file.blob
    data = blob.download
    mime = blob.content_type
    encoded = Base64.strict_encode64(data)
    "data:#{mime};base64,#{encoded}"
  rescue StandardError => e
    Rails.logger.error("AdRenderService: failed to encode background asset: #{e.message}")
    nil
  end

  def rasterize(svg_string)
    image = Vips::Image.new_from_buffer(svg_string, "")
    if @ad.jpg?
      image.jpegsave_buffer(Q: 90)
    else
      image.pngsave_buffer(compression: 6)
    end
  rescue Vips::Error => e
    raise Error, "Image rasterization failed: #{e.message}"
  end

  def attach_image(binary_data)
    format = @ad.jpg? ? "jpg" : "png"
    content_type = @ad.jpg? ? "image/jpeg" : "image/png"
    filename = "#{@ad.name.parameterize}-#{@version.audience.name.parameterize}-v#{@version.version_number}.#{format}"

    @version.rendered_image.attach(
      io: StringIO.new(binary_data),
      filename: filename,
      content_type: content_type
    )
  end

  def escape(str)
    str.to_s.encode(xml: :attr).gsub(/\A"|"\z/, "")
  end
end
