# frozen_string_literal: true

class SitemapController < ApplicationController
  def show
    config = Helios::Sitemap.configuration
    resp = config.s3_client.get_object(bucket: config.aws_bucket, key: config.s3_object_key)

    send_data resp.body.read,
              type: "application/gzip",
              filename: "sitemap.xml.gz",
              disposition: "inline"
  end
end
