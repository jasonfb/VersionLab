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
FactoryBot.define do
  factory :brand_profile do
    client
    organization_type { nil }
    industry { nil }
  end
end
