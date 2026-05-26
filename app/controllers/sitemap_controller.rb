# frozen_string_literal: true

require "open-uri"

class SitemapController < ApplicationController
  def show
    config = Helios::Sitemap.configuration
    url = "https://#{config.aws_bucket}.s3.#{config.aws_region}.amazonaws.com/#{config.s3_object_key}"

    gz_data = URI.open(url).read

    render plain: gz_data,
           content_type: "application/gzip",
           content_disposition: 'attachment; filename="sitemap.xml.gz"'
  end
end
