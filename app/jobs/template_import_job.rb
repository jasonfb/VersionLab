require "open-uri"
require "zip"

class TemplateImportJob < ApplicationJob
  queue_as :default

  retry_on ActiveStorage::FileNotFoundError, wait: 3.seconds, attempts: 3

  def perform(template_import_id)
    import = TemplateImport.find(template_import_id)
    import.update!(state: :processing)
    broadcast(import)

    case import.import_type
    when "bundled" then process_bundled(import)
    when "external" then process_external(import)
    end

    import.update!(state: :completed)
    broadcast(import)
  rescue => e
    import&.update!(state: :failed, error_message: e.message)
    broadcast(import) if import
    raise
  end

  private

  # ── Bundled (ZIP) ──────────────────────────────────────────────────────────

  def process_bundled(import)
    template = import.email_template
    folder = folder_name(template)
    client = template.client
    warnings = []
    asset_map = {} # "images/foo.png" => asset_id

    import.source_file.blob.open do |tmp|
      Zip::File.open(tmp.path) do |zip|
        html_entry = zip.find_entry("index.html") || zip.glob("*.html").first
        raise "No HTML file found in ZIP archive" unless html_entry

        html = html_entry.get_input_stream.read.force_encoding("UTF-8")

        # Upload every image in images/ folder
        zip.each do |entry|
          next if entry.directory?
          next unless entry.name.start_with?("images/")

          filename = File.basename(entry.name)
          data = entry.get_input_stream.read
          content_type = Marcel::MimeType.for(StringIO.new(data), name: filename)

          asset = create_asset(client, data, filename, content_type, folder)
          asset_map[entry.name] = asset.id
        end

        processed_html = replace_image_srcs(html, asset_map)
        template.update!(raw_source_html: processed_html, original_raw_source_html: processed_html)
        import.update!(warnings: warnings.to_json) unless warnings.empty?
      end
    end
  end

  # ── External (HTML with remote URLs) ──────────────────────────────────────

  def process_external(import)
    template = import.email_template
    folder = folder_name(template)
    client = template.client
    warnings = []
    asset_map = {} # "https://..." => asset_id

    html = import.source_file.blob.download.force_encoding("UTF-8")

    # Find all unique external image src values
    external_srcs = html.scan(/src=["'](\bhttps?:\/\/[^"']+)["']/).flatten.uniq

    external_srcs.each do |src|
      next if asset_map.key?(src)

      begin
        uri = URI.parse(src)
        data = uri.open(
          read_timeout: 15,
          open_timeout: 10,
          "User-Agent" => "VersionLab/1.0"
        ).read

        filename = File.basename(uri.path).presence || "image_#{SecureRandom.hex(4)}"
        filename = "#{SecureRandom.hex(4)}_#{filename}" unless filename.match?(/\.[a-z]{2,5}$/i)
        content_type = Marcel::MimeType.for(StringIO.new(data), name: filename)

        asset = create_asset(client, data, filename, content_type, folder)
        asset_map[src] = asset.id
      rescue => e
        warnings << "Failed to download #{src}: #{e.message}"
      end
    end

    processed_html = replace_image_srcs(html, asset_map)
    template.update!(raw_source_html: processed_html, original_raw_source_html: processed_html)
    import.update!(warnings: warnings.to_json) unless warnings.empty?
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  def folder_name(template)
    "templates/#{template.name.parameterize}"
  end

  def create_asset(client, data, filename, content_type, folder)
    asset = Asset.new(client: client, name: filename, folder: folder)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(data),
      filename: filename,
      content_type: content_type
    )
    asset.file.attach(blob)
    if blob.image?
      blob.analyze
      metadata = blob.metadata
      asset.width = metadata[:width]
      asset.height = metadata[:height]
      asset.standardized_ratio = Asset.snap_to_standard_ratio(asset.width, asset.height)
    end
    asset.save!
    asset
  end

  def replace_image_srcs(html, asset_map)
    return html if asset_map.empty?

    asset_map.each do |original_src, asset_id|
      replacement = "{{vl-asset:#{asset_id}}}"
      html = html.gsub(%(src="#{original_src}"), %(src="#{replacement}"))
      html = html.gsub(%(src='#{original_src}'), %(src="#{replacement}"))
    end
    html
  end

  def broadcast(import)
    ActionCable.server.broadcast(
      "template_import:#{import.id}",
      {
        state: import.state,
        email_template_id: import.email_template_id,
        warnings: import.warnings_list,
        error_message: import.error_message
      }
    )
  end
end
