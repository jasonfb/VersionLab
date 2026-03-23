class Ad < ApplicationRecord
  belongs_to :client
  belongs_to :campaign, optional: true
  belongs_to :ai_service, optional: true
  belongs_to :ai_model, optional: true
  belongs_to :background_asset, class_name: "Asset", optional: true

  has_one_attached :file
  has_one_attached :converted_svg
  has_many :ad_audiences, dependent: :destroy
  has_many :audiences, through: :ad_audiences
  has_many :ad_versions, dependent: :destroy

  enum :state, { setup: "setup", pending: "pending", merged: "merged", regenerating: "regenerating" }
  enum :background_type, { solid_color: "solid_color", image: "image" }
  enum :overlay_type, { solid: "solid", gradient: "gradient" }
  enum :versioning_mode, { retain_existing: "retain_existing", version_ads: "version_ads" }
  enum :output_format, { png: "png", jpg: "jpg" }

  validates :name, presence: true

  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(
      file, only_path: false, **ActionMailer::Base.default_url_options
    )
  end

  def file_content_type
    file.attached? ? file.blob.content_type : nil
  end

  def svg_url
    blob = converted_svg.attached? ? converted_svg : (file.attached? && file_content_type&.include?("svg") ? file : nil)
    return nil unless blob&.attached?
    Rails.application.routes.url_helpers.rails_blob_url(
      blob, only_path: false, **ActionMailer::Base.default_url_options
    )
  end
end
