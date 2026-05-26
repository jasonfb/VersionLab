# frozen_string_literal: true

class SitemapRefreshJob < ApplicationJob
  queue_as :default

  def perform
    Helios::Sitemap::RefreshService.call
  end
end
