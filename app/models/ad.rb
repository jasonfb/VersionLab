# == Schema Information
#
# Table name: ads
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  aspect_ratio              :string
#  background_color          :string           default("#000000")
#  background_type           :enum             default("solid_color")
#  classifications_confirmed :boolean          default(FALSE), not null
#  classified_layers         :jsonb            not null
#  file_warnings             :jsonb
#  height                    :integer
#  keep_background           :boolean          default(TRUE), not null
#  layer_overrides           :jsonb
#  name                      :string           not null
#  nlp_prompt                :text
#  output_format             :enum             default("png")
#  overlay_color             :string           default("#FFFFFF")
#  overlay_enabled           :boolean          default(FALSE), not null
#  overlay_opacity           :integer          default(80)
#  overlay_type              :enum             default("solid")
#  parsed_layers             :jsonb
#  play_button_color         :string           default("#FFFFFF")
#  play_button_enabled       :boolean          default(FALSE), not null
#  play_button_style         :string           default("circle_filled")
#  state                     :enum             default("setup"), not null
#  versioning_mode           :enum             default("retain_existing")
#  width                     :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  ai_model_id               :uuid
#  ai_service_id             :uuid
#  background_asset_id       :uuid
#  campaign_id               :uuid
#  client_id                 :uuid             not null
#
# Indexes
#
#  index_ads_on_client_id  (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#
class Ad < ApplicationRecord
  belongs_to :client
  belongs_to :campaign, optional: true
  belongs_to :ai_service, optional: true
  belongs_to :ai_model, optional: true
  belongs_to :background_asset, class_name: "Asset", optional: true

  has_one_attached :file
  has_one_attached :converted_svg
  has_one_attached :logo_file
  has_many :ad_audiences, dependent: :destroy
  has_many :audiences, through: :ad_audiences
  has_many :ad_versions, dependent: :destroy
  has_many :ad_resizes, dependent: :destroy
  has_many :ad_fonts, dependent: :destroy

  enum :state, { setup: "setup", resizing: "resizing", pending: "pending", merged: "merged", regenerating: "regenerating" }
  enum :background_type, { solid_color: "solid_color", image: "image" }
  enum :overlay_type, { solid: "solid", gradient: "gradient" }
  enum :versioning_mode, { retain_existing: "retain_existing", version_ads: "version_ads" }
  enum :output_format, { png: "png", jpg: "jpg" }

  validates :name, presence: true

  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true)
  end

  def file_content_type
    file.attached? ? file.blob.content_type : nil
  end

  def svg_url
    blob = converted_svg.attached? ? converted_svg : (file.attached? && file_content_type&.include?("svg") ? file : nil)
    return nil unless blob&.attached?
    Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true)
  end

  def logo_url
    return nil unless logo_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(logo_file, only_path: true)
  end
end
