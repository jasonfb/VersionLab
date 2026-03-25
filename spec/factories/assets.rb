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
