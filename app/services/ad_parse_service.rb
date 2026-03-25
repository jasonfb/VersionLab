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
    if layers.empty?
      layers = extract_clipped_layers(doc)
      # For clipped layers (outlined text), use pdf-reader to extract text content
      fill_clipped_layer_text(layers, reader.pages.first, height) if layers.any?
    end
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

    remove_nested_regions(layers)
  end

  # Remove regions fully contained within another region to avoid
  # overlapping text in rendered output.
  def remove_nested_regions(layers)
    layers.reject { |inner|
      ix = inner[:x].to_f
      iy = inner[:y].to_f
      iw = inner[:width].to_f
      ih = inner[:height].to_f

      layers.any? { |outer|
        next false if outer.equal?(inner)
        ox = outer[:x].to_f
        oy = outer[:y].to_f
        ow = outer[:width].to_f
        oh = outer[:height].to_f

        ox <= ix && oy <= iy &&
          (ox + ow) >= (ix + iw) &&
          (oy + oh) >= (iy + ih)
      }
    }.each_with_index.map { |layer, i|
      layer[:id] = "region_#{i}"
      layer
    }
  end

  # Use pdf-reader text runs to populate content for clipped regions.
  # PDF coordinates have origin at bottom-left (y-up); SVG at top-left (y-down).
  def fill_clipped_layer_text(layers, page, page_height)
    return if page_height.nil? || page_height <= 0

    runs = begin
      page.runs
    rescue => e
      Rails.logger.warn("AdParseService: could not extract PDF text runs: #{e.message}")
      return
    end
    return if runs.empty?

    layers.each do |layer|
      rx = layer[:x].to_f
      ry = layer[:y].to_f
      rw = layer[:width].to_f
      rh = layer[:height].to_f

      # Convert region bounds to PDF coordinate space
      pdf_y_bottom = page_height - (ry + rh)
      pdf_y_top    = page_height - ry

      # Collect runs whose baseline falls within this region (with generous padding
      # since clip-path bounding boxes may not perfectly match text extents)
      pad = 15
      matched = runs.select { |r|
        r.origin.x >= (rx - pad) &&
          r.origin.x <= (rx + rw + pad) &&
          r.origin.y >= (pdf_y_bottom - pad) &&
          r.origin.y <= (pdf_y_top + pad)
      }
      next if matched.empty?

      # Group into lines by y-proximity (within half a font size)
      lines = group_runs_into_lines(matched)

      # Build text: join characters within words, words with spaces, lines with spaces
      text = lines.map { |line_runs|
        join_runs_into_text(line_runs)
      }.join(" ")

      layer[:content] = text.strip
    end
  end

  def group_runs_into_lines(runs)
    sorted = runs.sort_by { |r| [ -r.origin.y, r.origin.x ] }
    lines = []
    current_line = [ sorted.first ]

    sorted[1..].each do |r|
      prev = current_line.last
      # Same line if y-values are within half the font size
      threshold = [ prev.font_size, r.font_size ].max * 0.5
      if (prev.origin.y - r.origin.y).abs <= threshold
        current_line << r
      else
        lines << current_line.sort_by { |x| x.origin.x }
        current_line = [ r ]
      end
    end
    lines << current_line.sort_by { |x| x.origin.x }
    lines
  end

  # Proportional width estimates (fraction of em-square) for common characters.
  # Used to detect word boundaries when reconstructing text from individual glyph runs.
  CHAR_WIDTH_RATIO = Hash.new(0.55).merge(
    "i" => 0.3,  "l" => 0.3,  "j" => 0.35, "!" => 0.3,  "." => 0.3,
    "," => 0.3,  ":" => 0.3,  ";" => 0.3,  "'" => 0.25, "|" => 0.3,
    "1" => 0.45, "f" => 0.4,  "r" => 0.4,  "t" => 0.4,
    "m" => 0.8,  "w" => 0.75,
    "I" => 0.4,  "J" => 0.45, "M" => 0.85, "W" => 0.85,
    "A" => 0.7,  "B" => 0.7,  "C" => 0.65, "D" => 0.7,  "E" => 0.6,
    "F" => 0.55, "G" => 0.7,  "H" => 0.7,  "K" => 0.65, "L" => 0.6,
    "N" => 0.7,  "O" => 0.75, "P" => 0.65, "Q" => 0.75, "R" => 0.65,
    "S" => 0.6,  "T" => 0.6,  "U" => 0.7,  "V" => 0.65, "X" => 0.65,
    "Y" => 0.6,  "Z" => 0.6
  ).freeze

  def join_runs_into_text(line_runs)
    return "" if line_runs.empty?
    return line_runs.first.text if line_runs.size == 1

    result = line_runs.first.text.dup
    line_runs.each_cons(2) do |prev, curr|
      gap = curr.origin.x - prev.origin.x
      advance_estimate = CHAR_WIDTH_RATIO[prev.text] * prev.font_size
      extra_space = gap - advance_estimate
      result << " " if extra_space > prev.font_size * 0.12
      result << curr.text
    end
    result
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
