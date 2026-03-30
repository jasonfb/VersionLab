class AdResizeService
  class Error < StandardError; end

  def initialize(ad, platforms:)
    @ad = ad
    @platforms = platforms
  end

  def call
    raise Error, "Ad has no dimensions" unless @ad.width.present? && @ad.height.present?
    raise Error, "Ad has no parsed layers" unless @ad.parsed_layers.present? && @ad.parsed_layers.any?

    deduped = AdPlatformSizes.deduplicated_sizes(@platforms)
    raise Error, "No valid sizes found for selected platforms" if deduped.empty?

    # Clear existing resizes (user went back to Step 1)
    @ad.ad_resizes.destroy_all

    deduped.map do |size_info|
      resize = @ad.ad_resizes.create!(
        platform_labels: size_info[:labels],
        width: size_info[:width],
        height: size_info[:height],
        aspect_ratio: compute_aspect_ratio(size_info[:width], size_info[:height]),
        state: :pending,
        resized_layers: resize_layers(size_info[:width], size_info[:height])
      )

      generate_resized_svg(resize)
      generate_preview(resize)
      resize.update!(state: :resized)
      resize
    rescue => e
      Rails.logger.error("AdResizeService failed for #{size_info[:width]}x#{size_info[:height]}: #{e.message}")
      resize&.update!(state: :failed) if resize&.persisted?
      resize
    end
  end

  private

  def resize_layers(target_width, target_height)
    scale_x = target_width.to_f / @ad.width
    scale_y = target_height.to_f / @ad.height

    (@ad.parsed_layers || []).map do |layer|
      resized = layer.dup
      resized["x"] = (layer["x"].to_f * scale_x).round.to_s if layer["x"]
      resized["y"] = (layer["y"].to_f * scale_y).round.to_s if layer["y"]
      resized["width"]  = (layer["width"].to_f * scale_x).round.to_s if layer["width"]
      resized["height"] = (layer["height"].to_f * scale_y).round.to_s if layer["height"]

      if layer["font_size"].present?
        original_size = layer["font_size"].to_f
        min_scale = [ scale_x, scale_y ].min
        resized["font_size"] = [ original_size * min_scale, 8 ].max.round.to_s
      end

      resized
    end
  end

  def generate_resized_svg(resize)
    svg_string = build_resized_svg(resize)

    resize.resized_svg.attach(
      io: StringIO.new(svg_string),
      filename: "resize-#{resize.width}x#{resize.height}.svg",
      content_type: "image/svg+xml"
    )
  end

  def generate_preview(resize)
    svg_data = resize.resized_svg.blob.download
    binary = rasterize(svg_data)

    format = @ad.jpg? ? "jpg" : "png"
    content_type = @ad.jpg? ? "image/jpeg" : "image/png"

    resize.preview_image.attach(
      io: StringIO.new(binary),
      filename: "preview-#{resize.width}x#{resize.height}.#{format}",
      content_type: content_type
    )
  end

  def build_resized_svg(resize)
    if @ad.converted_svg&.attached?
      rescale_svg(@ad.converted_svg.blob.download, resize.width, resize.height)
    elsif @ad.file&.attached? && @ad.file_content_type&.include?("svg")
      rescale_svg(@ad.file.blob.download, resize.width, resize.height)
    else
      fallback_svg(resize.width, resize.height)
    end
  end

  def rescale_svg(svg_data, target_width, target_height)
    doc = Nokogiri::XML(svg_data)
    root = doc.at_css("svg") || doc.root

    orig_w = @ad.width.to_f
    orig_h = @ad.height.to_f
    scale_x = target_width.to_f / orig_w
    scale_y = target_height.to_f / orig_h

    # Update viewBox to target dimensions so the SVG coordinate system
    # matches the new size — content is repositioned via the scale transform
    root["viewBox"] = "0 0 #{target_width} #{target_height}"
    root["width"] = target_width.to_s
    root["height"] = target_height.to_s

    # Wrap all existing children in a group that scales from original
    # coordinate space to the target coordinate space
    wrapper = Nokogiri::XML::Node.new("g", doc)
    wrapper["transform"] = "scale(#{scale_x}, #{scale_y})"

    # Move all children (defs, groups, text, images, etc.) into the wrapper
    children = root.children.to_a
    children.each { |child| wrapper.add_child(child) }
    root.add_child(wrapper)

    doc.to_xml
  end

  def fallback_svg(w, h)
    <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg xmlns="http://www.w3.org/2000/svg" width="#{w}" height="#{h}" viewBox="0 0 #{w} #{h}">
        <rect width="#{w}" height="#{h}" fill="#333333" />
        <text x="#{w / 2}" y="#{h / 2}" text-anchor="middle" dominant-baseline="middle" fill="#999" font-size="14">#{w}x#{h}</text>
      </svg>
    SVG
  end

  def rasterize(svg_string)
    image = Vips::Image.new_from_buffer(svg_string, "")
    if @ad.jpg?
      image.jpegsave_buffer(Q: 85)
    else
      image.pngsave_buffer(compression: 6)
    end
  rescue Vips::Error => e
    raise Error, "Preview rasterization failed: #{e.message}"
  end

  def compute_aspect_ratio(width, height)
    return nil unless width > 0 && height > 0
    d = gcd(width, height)
    "#{width / d}:#{height / d}"
  end

  def gcd(a, b)
    b == 0 ? a : gcd(b, a % b)
  end
end
