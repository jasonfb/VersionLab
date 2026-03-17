require "open-uri"

class FetchLinkPreviewJob < ApplicationJob
  queue_as :default

  def perform(campaign_link_id)
    link = CampaignLink.find_by(id: campaign_link_id)
    return unless link

    uri = URI.parse(link.url)
    html = URI.open(uri, read_timeout: 5, open_timeout: 5, "User-Agent" => "VersionLab/1.0").read
    doc = Nokogiri::HTML(html)

    title = doc.at("meta[property='og:title']")&.[]("content") ||
            doc.at("title")&.text&.strip

    description = doc.at('meta[property="og:description"]')&.[]("content") ||
                  doc.at('meta[name="description"]')&.[]("content")

    image_url = doc.at('meta[property="og:image"]')&.[]("content")

    link.update!(
      title: title&.truncate(255),
      link_description: description&.truncate(500),
      image_url: image_url,
      fetched_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.warn("FetchLinkPreviewJob failed for link #{campaign_link_id}: #{e.message}")
    link&.update_columns(fetched_at: Time.current)
  ensure
    CampaignSummaryJob.perform_later(link.campaign_id) if link
  end
end
