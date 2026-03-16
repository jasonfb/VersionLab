class Asset < ApplicationRecord
  belongs_to :project

  has_one_attached :file

  STANDARD_RATIOS = [
    { key: "hero_3_1",        value: 3.0 / 1 },
    { key: "banner_2_1",      value: 2.0 / 1 },
    { key: "widescreen_16_9", value: 16.0 / 9 },
    { key: "square_1_1",      value: 1.0 / 1 },
    { key: "portrait_4_5",    value: 4.0 / 5 },
  ].freeze

  def self.snap_to_standard_ratio(width, height)
    return nil if width.nil? || height.nil? || height.zero?

    native = width.to_f / height
    STANDARD_RATIOS.min_by { |r| (Math.log(native) - Math.log(r[:value])).abs }[:key]
  end

  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(
      file,
      only_path: false,
      **ActionMailer::Base.default_url_options
    )
  end
end
