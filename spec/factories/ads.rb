FactoryBot.define do
  factory :ad do
    client
    name { "Test Ad" }
    state { "setup" }
  end
end
