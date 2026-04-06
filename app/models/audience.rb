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
class Audience < ApplicationRecord
  belongs_to :client

  validates :name, presence: true
end
