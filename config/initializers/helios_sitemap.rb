# frozen_string_literal: true

Helios::Sitemap.configure do |config|
  # The canonical host for your sitemap URLs
  config.default_host = "https://versionlab.io"

  # S3 settings (defaults read from ENV vars)
  # config.aws_region = ENV["AWS_REGION"]
  # config.aws_bucket = ENV["AWS_SITEMAP_BUCKET"]
  # config.aws_access_key_id = ENV["AWS_ACCESS_KEY_ID"]
  # config.aws_secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
  # config.s3_object_key = "sitemaps/sitemap.xml.gz"

  # Define your sitemap entries.
  # The block receives a SitemapGenerator::Sitemap instance.
  config.sitemap_entries = ->(sitemap) {
    sitemap.add "/", changefreq: "daily", priority: 0.9
    # sitemap.add "/about", changefreq: "weekly"

    # Dynamic entries from your database:
    # Page.published.find_each do |page|
    #   sitemap.add "/#{page.slug}", lastmod: page.updated_at, changefreq: "weekly"
    # end
  }

  # IndexNow integration (optional)
  # config.indexnow_domain = ENV["INDEXNOW_DOMAIN"]
  # config.indexnow_api_key = ENV["INDEXNOW_API_KEY"]
  # config.indexnow_urls = -> {
  #   Page.published.map { |p| "https://example.com/#{p.slug}" }
  # }
end
