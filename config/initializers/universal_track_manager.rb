# frozen_string_literal: true

UniversalTrackManager.configure do |config|
  config.track_ips = true
  config.track_utms = true
  config.track_user_agent = true
  config.table_prefix = 'utm'

  config.campaign_columns = 'utm_source,utm_medium,utm_campaign,utm_term,utm_content'
  # config.track_referrer = true
  # config.track_gclid_present = true # be sure to add gclid to campaign_columns
end
