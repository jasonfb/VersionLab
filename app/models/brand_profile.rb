# == Schema Information
#
# Table name: brand_profiles
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  approved_vocabulary  :text             default([]), is an Array
#  blocked_vocabulary   :text             default([]), is an Array
#  bold_links           :boolean          default(FALSE), not null
#  color_palette        :text             default([]), is an Array
#  core_programs        :text             default([]), is an Array
#  italic_links         :boolean          default(FALSE), not null
#  link_color           :string
#  mission_statement    :text
#  organization_name    :string
#  primary_domain       :string
#  underline_links      :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  client_id            :uuid             not null
#  industry_id          :uuid
#  organization_type_id :uuid
#
# Indexes
#
#  index_brand_profiles_on_client_id  (client_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#  fk_rails_...  (industry_id => industries.id)
#  fk_rails_...  (organization_type_id => organization_types.id)
#
class BrandProfile < ApplicationRecord
  belongs_to :client
  belongs_to :organization_type, optional: true
  belongs_to :industry, optional: true

  has_many :brand_profile_primary_audiences, dependent: :destroy
  has_many :primary_audiences, through: :brand_profile_primary_audiences

  has_many :brand_profile_tone_rules, dependent: :destroy
  has_many :tone_rules, through: :brand_profile_tone_rules

  has_many :brand_profile_geographies, dependent: :destroy
  has_many :geographies, through: :brand_profile_geographies
end
