# == Schema Information
#
# Table name: assets
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  folder             :string
#  height             :integer
#  name               :string
#  standardized_ratio :enum
#  width              :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  client_id          :uuid             not null
#
# Indexes
#
#  index_assets_on_client_id  (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#
FactoryBot.define do
  factory :asset do
    client

    after(:build) do |asset|
      asset.file.attach(
        io: StringIO.new("fake image data"),
        filename: "test.png",
        content_type: "image/png"
      )
    end
  end
end
