class AdParseService
  # Known platform aspect ratios: [width_ratio, height_ratio, platforms]
  PLATFORM_RATIOS = [
    [ 1, 1,    [ "Facebook Feed", "Instagram Square", "LinkedIn Square", "Pinterest Square", "Reddit Feed", "Threads Feed", "X Square" ] ],
    [ 4, 5,    [ "Instagram Portrait" ] ],
    [ 9, 16,   [ "Instagram Story", "Facebook Story", "Snapchat", "TikTok In-Feed" ] ],
    [ 16, 9,   [ "X Single Image" ] ],
    [ 300, 157, [ "Facebook Landscape", "Reddit Feed" ] ],
    [ 400, 209, [ "LinkedIn Single Image" ] ],
    [ 2, 3,    [ "Pinterest Standard Pin" ] ],
    [ 364, 45, [ "Google Leaderboard" ] ],
    [ 6, 5,    [ "Google Medium Rectangle", "Google Large Rectangle", "YouTube Display Banner" ] ],
    [ 1, 2,    [ "Google Half Page" ] ],
    [ 4, 15,   [ "Google Wide Skyscraper" ] ],
    [ 48, 7,   [ "YouTube Overlay" ] ]
  ].freeze

  def initialize(ad)
    @ad = ad
  end

  def call
    return unless @ad.file.attached?

    content_type = @ad.file.blob.content_type
    blob_data = @ad.file.blob.download

    result = if content_type.include?("svg")
      parse_svg(blob_data)
    elsif content_type.include?("pdf")
      parse_pdf(blob_data)
    else
      { layers: [], warnings: [ { type: "unsupported_format", message: "Only SVG and PDF files are supported." } ], width: nil, height: nil, aspect_ratio: nil }
    end

    @ad.update!(
      parsed_layers: result[:layers],
      file_warnings: result[:warnings],
      width: result[:width],
      height: result[:height],
      aspect_ratio: result[:aspect_ratio]
    )

    result
  end

  private

  def parse_svg(data)
    doc = Nokogiri::XML(data)
    root = doc.at_css("svg") || doc.root

    width, height = extract_svg_dimensions(root)
    layers = extract_svg_text_layers(doc)
    warnings = check_svg_warnings(layers, doc)
    aspect_ratio = compute_aspect_ratio(width, height)

    { layers: layers, warnings: warnings, width: width, height: height, aspect_ratio: aspect_ratio }
  rescue => e
    Rails.logger.error("AdParseService SVG parse error: #{e.message}")
    { layers: [], warnings: [ { type: "parse_error", message: "Could not parse SVG: #{e.message}" } ], width: nil, height: nil, aspect_ratio: nil }
  end

  def extract_svg_dimensions(root)
    # Try viewBox first, then width/height attributes
    if root["viewBox"].present?
      parts = root["viewBox"].strip.split(/[\s,]+/)
      if parts.length == 4
        return [ parts[2].to_f.round, parts[3].to_f.round ]
      end
    end

    w = parse_svg_length(root["width"])
    h = parse_svg_length(root["height"])
    [ w, h ]
  end

  def parse_svg_length(value)
    return nil if value.blank?
    value.to_f.round
  end

  def extract_svg_text_layers(doc)
    layers = []
    index = 0

    doc.css("text, tspan").each do |node|
      content = node.text.strip
      next if content.blank?
      next if node.name == "tspan" && node.parent.name == "text"

      layer_id = node["id"].presence || node["inkscape:label"].presence || "layer_#{index}"
      font_size = node["font-size"] || node.css_style("font-size")
      font_family = node["font-family"] || node.css_style("font-family")
      x = node["x"]
      y = node["y"]

      layers << {
        id: layer_id,
        type: "text",
        content: content,
        font_size: font_size,
        font_family: font_family,
        x: x,
        y: y
      }
      index += 1
    end

    layers
  end

  def check_svg_warnings(layers, doc)
    warnings = []

    if layers.empty?
      warnings << {
        type: "no_text_layers",
        message: "No editable text layers found. Ensure live text is preserved (not converted to outlines)."
      }
    end

    # Check for potential outlined text (paths with no text siblings)
    path_count = doc.css("path").length
    if path_count > 0 && layers.empty?
      warnings << {
        type: "possible_outlined_text",
        message: "The file contains vector paths but no live text. Text may have been converted to outlines."
      }
    end

    # Check for very small font sizes
    layers.each do |layer|
      next unless layer[:font_size].present?
      size = layer[:font_size].to_f
      if size > 0 && size < 8
        warnings << {
          type: "font_size_too_small",
          layer_id: layer[:id],
          message: "Layer '#{layer[:id]}' has a very small font size (#{layer[:font_size]}). Minimum recommended size is 8pt."
        }
      end
    end

    warnings
  end

  def parse_pdf(data)
    require "pdf-reader"
    require "tempfile"

    io = StringIO.new(data)
    reader = PDF::Reader.new(io)
    warnings = []

    if reader.page_count > 1
      warnings << {
        type: "multiple_pages",
        message: "This PDF has #{reader.page_count} pages. Only the first page will be used."
      }
    end

    # Convert PDF to SVG using pdftocairo (poppler)
    svg_data = convert_pdf_to_svg(data)
    unless svg_data
      return {
        layers: [],
        warnings: warnings + [ { type: "conversion_error", message: "Could not convert PDF to SVG. Ensure pdftocairo (poppler) is installed." } ],
        width: nil, height: nil, aspect_ratio: nil
      }
    end

    # Attach the converted SVG to the ad
    @ad.converted_svg.attach(
      io: StringIO.new(svg_data),
      filename: "#{@ad.file.filename.base}.svg",
      content_type: "image/svg+xml"
    )

    # Parse the converted SVG for dimensions and text layers
    doc = Nokogiri::XML(svg_data)
    root = doc.at_css("svg") || doc.root
    width, height = extract_svg_dimensions(root)
    aspect_ratio = compute_aspect_ratio(width, height)

    # Try native SVG text elements first; fall back to clipped image regions
    layers = extract_svg_text_layers(doc)
    layers = extract_clipped_layers(doc) if layers.empty?
    warnings += check_svg_warnings(layers, doc) if layers.any? { |l| l[:type] == "text" && l[:content].present? }

    if layers.empty?
      warnings << { type: "no_text_layers", message: "No editable text layers found. Ensure live text is preserved (not converted to outlines)." }
    end

    { layers: layers, warnings: warnings, width: width, height: height, aspect_ratio: aspect_ratio }
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
    Rails.logger.error("AdParseService PDF parse error: #{e.message}")
    { layers: [], warnings: [ { type: "parse_error", message: "Could not parse PDF: #{e.message}" } ], width: nil, height: nil, aspect_ratio: nil }
  rescue => e
    Rails.logger.error("AdParseService PDF unexpected error: #{e.message}")
    { layers: [], warnings: [ { type: "parse_error", message: "PDF parsing failed: #{e.message}" } ], width: nil, height: nil, aspect_ratio: nil }
  end

  # Extract layers from a PDF-converted SVG where text is rendered as clipped image groups.
  # Each text region has a pair of nested clip-path groups: outer = bounding rect, inner = glyph outlines.
  def extract_clipped_layers(doc)
    layers = []
    body_groups = doc.at_css("svg").children.select { |n| n.element? && n.name == "g" }

    body_groups.each_with_index do |outer_g, i|
      clip_id = outer_g["clip-path"]&.match(/url\(#([^)]+)\)/)&.[](1)
      next unless clip_id

      clip_el = doc.at_css("##{clip_id}")
      next unless clip_el

      bbox = bounding_rect_from_clip(clip_el)
      next unless bbox

      layers << {
        id: "region_#{i}",
        type: "text",
        content: "",
        x: bbox[:x].to_s,
        y: bbox[:y].to_s,
        width: bbox[:w].to_s,
        height: bbox[:h].to_s
      }
    end

    layers
  end

  def bounding_rect_from_clip(clip_el)
    path = clip_el.at_css("path")
    return nil unless path

    d = path["d"].to_s
    coords = d.scan(/-?[\d.]+/).map(&:to_f)
    return nil if coords.length < 8

    xs = coords.select.with_index { |_, i| i.even? }
    ys = coords.select.with_index { |_, i| i.odd? }
    x1, x2 = xs.min, xs.max
    y1, y2 = ys.min, ys.max

    { x: x1.round, y: y1.round, w: (x2 - x1).round, h: (y2 - y1).round }
  end

  def convert_pdf_to_svg(pdf_data)
    pdf_file = Tempfile.new([ "ad_input", ".pdf" ])
    svg_file = Tempfile.new([ "ad_output", ".svg" ])
    begin
      pdf_file.binmode
      pdf_file.write(pdf_data)
      pdf_file.flush

      # -f 1 -l 1: first page only; -svg: SVG output
      success = system(
        "pdftocairo", "-svg", "-f", "1", "-l", "1",
        pdf_file.path, svg_file.path
      )

      return nil unless success && File.exist?(svg_file.path) && File.size(svg_file.path) > 0
      File.read(svg_file.path)
    ensure
      pdf_file.close!
      svg_file.close!
    end
  end

  def compute_aspect_ratio(width, height)
    return nil unless width.present? && height.present? && width > 0 && height > 0

    d = gcd(width.round, height.round)
    w = width.round / d
    h = height.round / d
    "#{w}:#{h}"
  end

  def gcd(a, b)
    b == 0 ? a : gcd(b, a % b)
  end
end
