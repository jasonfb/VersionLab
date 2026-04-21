require 'rails_helper'

RSpec.describe AudienceSamples do
  describe "SAMPLES" do
    it "is frozen" do
      expect(AudienceSamples::SAMPLES).to be_frozen
    end

    it "contains multiple samples" do
      expect(AudienceSamples::SAMPLES.size).to be >= 4
    end

    it "each sample has required fields" do
      AudienceSamples::SAMPLES.each do |sample|
        expect(sample[:name]).to be_present
        expect(sample[:details]).to be_present
        expect(sample[:executive_summary]).to be_present
        expect(sample[:demographics_and_financial_capacity]).to be_present
        expect(sample[:lapse_diagnosis]).to be_present
        expect(sample[:motivational_drivers_and_messaging_framework]).to be_present
      end
    end

    it "includes Budget-Conscious / Deal Seekers" do
      names = AudienceSamples::SAMPLES.map { |s| s[:name] }
      expect(names).to include("Budget-Conscious / Deal Seekers")
    end

    it "includes Gen Z audience" do
      names = AudienceSamples::SAMPLES.map { |s| s[:name] }
      expect(names).to include("Gen Z (Ages ~18–26)")
    end
  end
end
