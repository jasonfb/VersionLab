module AdPlatformSizes
  # Returns all platforms with their sizes, structured like the old PLATFORMS hash.
  # Used by the API to serve platform data to the frontend.
  def self.all_platforms
    AdPlatform.ordered.includes(:ad_platform_sizes).map do |platform|
      [
        platform.name,
        platform.ad_platform_sizes.ordered.map { |s| { name: s.name, width: s.width, height: s.height } }
      ]
    end.to_h
  end

  # selected_platforms can be:
  #   - Hash/object: { "Platform Name" => ["Size1", "Size2"] } for specific sizes
  #     (nil value means all sizes for that platform)
  #   - Array: ["Platform Name", ...] for all sizes (legacy)
  # custom_sizes is an optional array of { label:, width:, height: } hashes
  def self.deduplicated_sizes(selected_platforms, custom_sizes: [])
    by_dims = {}

    entries = if selected_platforms.is_a?(Hash)
      selected_platforms
    else
      Array(selected_platforms).index_with { |_| nil }
    end

    platform_names = entries.keys
    platforms = AdPlatform.where(name: platform_names).includes(:ad_platform_sizes)

    platforms.each do |platform|
      size_names = entries[platform.name]
      sizes = if size_names.present?
        platform.ad_platform_sizes.select { |s| size_names.include?(s.name) }
      else
        platform.ad_platform_sizes
      end

      sizes.each do |size|
        key = "#{size.width}x#{size.height}"
        by_dims[key] ||= { width: size.width, height: size.height, labels: [] }
        by_dims[key][:labels] << { "platform" => platform.name, "size_name" => size.name }
      end
    end

    Array(custom_sizes).each do |cs|
      w = cs[:width].to_i
      h = cs[:height].to_i
      next if w <= 0 || h <= 0

      key = "#{w}x#{h}"
      by_dims[key] ||= { width: w, height: h, labels: [] }
      by_dims[key][:labels] << { "platform" => "Custom", "size_name" => cs[:label].presence || key }
    end

    by_dims.values
  end
end
