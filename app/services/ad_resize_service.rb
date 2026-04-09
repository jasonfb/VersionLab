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

    engine = AdLayout::LayoutEngine.new(@ad)

    deduped.map do |size_info|
      build_resize(engine, size_info[:width], size_info[:height], size_info[:labels])
    end
  end

  # Destroy and rebuild a single existing resize, preserving its dimensions
  # and platform_labels. Used when the user changes layer classifications and
  # wants the layout re-flowed without regenerating every size.
  def self.rebuild(resize)
    ad = resize.ad
    width = resize.width
    height = resize.height
    labels = resize.platform_labels
    resize.destroy!

    engine = AdLayout::LayoutEngine.new(ad)
    new(ad, platforms: {}).send(:build_resize, engine, width, height, labels)
  end

  private

  def build_resize(engine, width, height, labels)
    layout_result = engine.compute_layout(width, height)

    resize = @ad.ad_resizes.create!(
      platform_labels: labels,
      width: width,
      height: height,
      aspect_ratio: compute_aspect_ratio(width, height),
      state: :pending,
      resized_layers: layout_result.layers
    )

    generate_resized_svg(resize, layout_result)
    generate_preview(resize)
    resize.update!(state: :resized)
    resize
  rescue => e
    Rails.logger.error("AdResizeService failed for #{width}x#{height}: #{e.message}")
    resize&.update!(state: :failed) if resize&.persisted?
    resize
  end

  def generate_resized_svg(resize, layout_result)
    svg_string = build_resized_svg(resize, layout_result)

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

  def build_resized_svg(resize, layout_result)
    # Use SvgComposer for classified ads; legacy rescale for old ads
    if @ad.classifications_confirmed?
      AdLayout::SvgComposer.new(@ad).compose(layout_result)
    elsif @ad.converted_svg&.attached?
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

    # Ensure viewBox is set to original dimensions for proportional scaling
    unless root["viewBox"]
      root["viewBox"] = "0 0 #{@ad.width} #{@ad.height}"
    end

    root["width"] = target_width.to_s
    root["height"] = target_height.to_s

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
