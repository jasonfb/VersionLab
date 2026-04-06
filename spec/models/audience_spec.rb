# == Schema Information
#
# Table name: audiences
# Database name: primary
#
#  id                                           :uuid             not null, primary key
#  creative_and_imagery_rules                   :text
#  demographics_and_financial_capacity          :text
#  details                                      :text
#  executive_summary                            :text
#  lapse_diagnosis                              :text
#  motivational_drivers_and_messaging_framework :text
#  name                                         :string           not null
#  prohibited_patterns                          :text
#  relationship_state_and_pre_lapse_indicators  :text
#  risk_scoring_model                           :text
#  strategic_reactivation_and_upgrade_cadence   :text
#  success_indicators_and_macro_trends          :text
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  client_id                                    :uuid             not null
#
require 'rails_helper'

RSpec.describe Audience, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a name" do
      audience = build(:audience, name: nil)
      expect(audience).not_to be_valid
      expect(audience.errors[:name]).to include("can't be blank")
    end
  end
end
