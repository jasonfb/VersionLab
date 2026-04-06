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
FactoryBot.define do
  factory :ad do
    client
    name { "Test Ad" }
    state { "setup" }
  end
end
