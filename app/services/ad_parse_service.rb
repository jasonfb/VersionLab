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

    # Warn if no logo/image element was detected
    has_logo = result[:layers].any? { |l| l[:type] == "image" }
    unless has_logo
      result[:warnings] << {
        type: "no_logo_detected",
        message: "No separate logo element was detected. If your logo is part of the background image, it will be replaced when the background is swapped. You can upload a logo separately in the ad editor."
      }
    end

    @ad.update!(
      parsed_layers: result[:layers],
      file_warnings: result[:warnings],
      width: result[:width],
      height: result[:height],
      aspect_ratio: result[:aspect_ratio]
    )

    AdClassifyService.new(@ad).call if result[:layers].any?

    result
  end

  private

  def parse_svg(data)
    doc = Nokogiri::XML(data)
    root = doc.at_css("svg") || doc.root

    width, height = extract_svg_dimensions(root)
    layers = extract_svg_text_layers(doc)
    layers += extract_svg_image_layers(doc, width, height)
    layers += extract_svg_shape_layers(doc, width, height)
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
      font_weight = node["font-weight"] || node.css_style("font-weight")
      fill = node["fill"] || node.css_style("fill")
      x = node["x"]
      y = node["y"]

      layer = {
        id: layer_id,
        type: "text",
        content: content,
        font_size: font_size,
        font_family: font_family,
        x: x,
        y: y
      }
      layer[:font_weight] = font_weight if font_weight.present?
      layer[:fill] = fill if fill.present?
      layers << layer
      index += 1
    end

    layers
  end

  def extract_svg_image_layers(doc, canvas_width, canvas_height)
    layers = []
    index = 0

    doc.css("image").each do |node|
      href = node["href"] || node["xlink:href"]
      next if href.blank?

      x = node["x"].to_f
      y = node["y"].to_f
      w = node["width"].to_f
      h = node["height"].to_f

      # Skip images that cover the full canvas (likely background fills, not logos)
      next if canvas_width && canvas_height && w >= canvas_width * 0.95 && h >= canvas_height * 0.95

      layer_id = node["id"].presence || "image_#{index}"

      layers << {
        id: layer_id,
        type: "image",
        href: href,
        x: x.round.to_s,
        y: y.round.to_s,
        width: w.round.to_s,
        height: h.round.to_s
      }
      index += 1
    end

    layers
  end

  # Extract filled shape elements (rects + paths) so the classifier can later
  # detect button backgrounds behind CTAs. Shapes are stored as a separate
  # layer type and excluded from classified output unless attached to a CTA.
  def extract_svg_shape_layers(doc, canvas_width, canvas_height)
    layers = []
    return layers unless canvas_width && canvas_height && canvas_width > 0 && canvas_height > 0
    canvas_area = canvas_width.to_f * canvas_height.to_f
    index = 0

    doc.css("rect").each do |node|
      fill = read_fill(node)
      next if fill.blank?
      x = node["x"].to_f
      y = node["y"].to_f
      w = node["width"].to_f
      h = node["height"].to_f
      next unless w > 0 && h > 0
      next if w * h >= canvas_area * 0.5  # too large to be a button
      next if w * h < 50  # too tiny to matter

      layers << {
        id: "shape_#{index}",
        type: "shape",
        shape: "rect",
        fill: fill,
        rx: (node["rx"] || node["ry"]).to_f,
        x: x.round.to_s,
        y: y.round.to_s,
        width: w.round.to_s,
        height: h.round.to_s
      }
      index += 1
    end

    doc.css("path").each do |node|
      fill = read_fill(node)
      next if fill.blank? || fill.casecmp("none").zero?
      bbox = path_bounding_box(node["d"].to_s)
      next unless bbox
      area = bbox[:w] * bbox[:h]
      next if area >= canvas_area * 0.5
      next if area < 50

      layers << {
        id: "shape_#{index}",
        type: "shape",
        shape: "path",
        fill: fill,
        rx: 0.0, # path-based corners; we'll round visually using min(w,h)*0.15
        x: bbox[:x].round.to_s,
        y: bbox[:y].round.to_s,
        width: bbox[:w].round.to_s,
        height: bbox[:h].round.to_s
      }
      index += 1
    end

    layers
  end

  def read_fill(node)
    fill = node["fill"]
    if fill.blank? && node["style"].present?
      m = node["style"].match(/(?:^|;)\s*fill\s*:\s*([^;]+)/i)
      fill = m[1].strip if m
    end
    fill
  end

  def path_bounding_box(d)
    return nil if d.blank?
    coords = d.scan(/-?\d+(?:\.\d+)?/).map(&:to_f)
    return nil if coords.length < 4
    xs = coords.each_slice(2).map(&:first)
    ys = coords.each_slice(2).map(&:last).compact
    return nil if xs.empty? || ys.empty?
    x1, x2 = xs.min, xs.max
    y1, y2 = ys.min, ys.max
    w = x2 - x1
    h = y2 - y1
    return nil if w <= 0 || h <= 0
    { x: x1, y: y1, w: w, h: h }
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

    # Extract and store embedded fonts
    extract_fonts(reader)

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
    layers += extract_svg_image_layers(doc, width, height)
    layers += extract_svg_shape_layers(doc, width, height)
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

      # Capture the source image href from the inner <use> element (if any)
      use_el = outer_g.at_css("use")
      source_href = nil
      if use_el
        ref_id = (use_el["href"] || use_el["xlink:href"]).to_s.sub("#", "")
        source_el = doc.at_css("##{ref_id}") if ref_id.present?
        source_href = (source_el["href"] || source_el["xlink:href"]) if source_el&.name == "image"
      end

      layer = {
        id: "region_#{i}",
        type: "text",
        content: "",
        x: bbox[:x].to_s,
        y: bbox[:y].to_s,
        width: bbox[:w].to_s,
        height: bbox[:h].to_s
      }
      layer[:href] = source_href if source_href
      layers << layer
    end

    remove_nested_regions(layers)
  end

  # Remove regions that are near-duplicates of another region (>70% area overlap)
  # to avoid overlapping text in rendered output. Small regions that happen to fall
  # within a larger region's bounding box are preserved (e.g. a logo inside a CTA area).
  def remove_nested_regions(layers)
    layers.reject { |inner|
      ix = inner[:x].to_f
      iy = inner[:y].to_f
      iw = inner[:width].to_f
      ih = inner[:height].to_f
      inner_area = iw * ih

      layers.any? { |outer|
        next false if outer.equal?(inner)
        ox = outer[:x].to_f
        oy = outer[:y].to_f
        ow = outer[:width].to_f
        oh = outer[:height].to_f
        outer_area = ow * oh

        next false unless ox <= ix && oy <= iy &&
          (ox + ow) >= (ix + iw) &&
          (oy + oh) >= (iy + ih)

        # Only remove if the inner region covers most of the outer region (near-duplicate)
        outer_area > 0 && inner_area / outer_area > 0.7
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

    claimed_runs = Set.new

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
        !claimed_runs.include?(r.object_id) &&
          r.origin.x >= (rx - pad) &&
          r.origin.x <= (rx + rw + pad) &&
          r.origin.y >= (pdf_y_bottom - pad) &&
          r.origin.y <= (pdf_y_top + pad)
      }
      next if matched.empty?

      # Claim these runs so they aren't reused by another region
      matched.each { |r| claimed_runs.add(r.object_id) }

      # Group into lines by y-proximity (within half a font size)
      lines = group_runs_into_lines(matched)

      # Build text: join characters within words, words with spaces, lines with spaces
      text = lines.map { |line_runs|
        join_runs_into_text(line_runs)
      }.join(" ")

      layer[:content] = text.strip

      # Capture the dominant font size from the matched runs
      size_counts = matched.group_by { |r| r.font_size.round(1) }
      dominant_size = size_counts.max_by { |_, rs| rs.length }&.first
      layer[:font_size] = dominant_size.round.to_s if dominant_size

      # Detect bold from content pattern (all-caps text is usually a bold headline)
      if text.strip == text.strip.upcase && text.strip.length > 3
        layer[:is_bold] = true
      end
    end

    # Regions with no text content that are contained within a text region are sub-layers
    # (e.g. a CTA button's inner rendering layer) — remove them.
    # Standalone empty regions outside of any text region are kept as image elements.
    layers.reject! do |layer|
      next false if layer[:content].present?

      ix = layer[:x].to_f
      iy = layer[:y].to_f
      iw = layer[:width].to_f
      ih = layer[:height].to_f

      layers.any? do |other|
        next false if other.equal?(layer)
        next false if other[:content].blank?
        ox = other[:x].to_f
        oy = other[:y].to_f
        ow = other[:width].to_f
        oh = other[:height].to_f
        ox <= ix && oy <= iy && (ox + ow) >= (ix + iw) && (oy + oh) >= (iy + ih)
      end
    end

    # Re-index region IDs after removal
    layers.each_with_index { |layer, i| layer[:id] = "region_#{i}" }

    # Remaining regions with no text content are standalone image elements (logos, icons)
    layers.each do |layer|
      next unless layer[:content].blank?
      layer[:type] = "image"
    end

    # Try to assign font families from embedded AdFont records
    assign_font_families(layers)
  end

  def assign_font_families(layers)
    fonts = @ad.ad_fonts.to_a
    return if fonts.empty?

    bold_font = fonts.find { |f| f.font_name =~ /bold|black|heavy/i }
    light_font = fonts.find { |f| f.font_name =~ /light|regular|medium/i } || fonts.find { |f| f.font_name !~ /bold|black|heavy/i }

    layers.each do |layer|
      next unless layer[:font_size]
      if layer[:is_bold] && bold_font
        layer[:font_family] = bold_font.font_name
      elsif light_font
        layer[:font_family] = light_font.font_name
      elsif fonts.first
        layer[:font_family] = fonts.first.font_name
      end
    end
  end

  def extract_fonts(reader)
    @ad.ad_fonts.destroy_all

    font_descriptors = []
    reader.objects.each do |_ref, obj|
      next unless obj.is_a?(Hash) && obj[:Type] == :FontDescriptor && obj[:FontFile2]
      font_descriptors << obj
    end

    if font_descriptors.empty?
      warnings = @ad.file_warnings || []
      warnings << {
        "type" => "missing_embedded_fonts",
        "message" => "This PDF has no embedded fonts. Please re-export with fonts embedded and re-upload."
      }
      @ad.update!(file_warnings: warnings)
      return
    end

    font_descriptors.each do |descriptor|
      font_name = descriptor[:FontName].to_s.sub(/\A[A-Z]{6}\+/, "")
      postscript_name = descriptor[:FontName].to_s
      stream = reader.objects.deref(descriptor[:FontFile2])
      next unless stream.is_a?(PDF::Reader::Stream)

      data = stream.unfiltered_data
      next if data.blank?

      ad_font = @ad.ad_fonts.create!(
        font_name: font_name,
        postscript_name: postscript_name
      )

      ad_font.font_file.attach(
        io: StringIO.new(data),
        filename: "#{font_name.parameterize}.ttf",
        content_type: "font/ttf"
      )
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
