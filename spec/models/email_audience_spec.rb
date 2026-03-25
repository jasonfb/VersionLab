require 'rails_helper'

RSpec.describe EmailAudience, type: :model do
  describe "associations" do
    it "belongs to email" do
      assoc = described_class.reflect_on_association(:email)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to audience" do
      assoc = described_class.reflect_on_association(:audience)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
