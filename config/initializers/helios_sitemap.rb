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
    # Marketing pages
    sitemap.add "/", changefreq: "daily", priority: 0.9
    sitemap.add "/pricing", changefreq: "weekly", priority: 0.8
    sitemap.add "/contact", changefreq: "monthly", priority: 0.6

    # Blog posts (helios-press)
    Helios::Press::Post.published.find_each do |post|
      sitemap.add "/#{post.slug}", lastmod: post.updated_at, changefreq: "weekly", priority: 0.7
    end
  }

  # IndexNow integration (optional)
  # config.indexnow_domain = ENV["INDEXNOW_DOMAIN"]
  # config.indexnow_api_key = ENV["INDEXNOW_API_KEY"]
  # config.indexnow_urls = -> {
  #   Page.published.map { |p| "https://example.com/#{p.slug}" }
  # }
end
