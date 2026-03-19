class AddAudienceIntelligenceFields < ActiveRecord::Migration[8.1]
  def change
    add_column :audiences, :executive_summary, :text
    add_column :audiences, :demographics_and_financial_capacity, :text
    add_column :audiences, :lapse_diagnosis, :text
    add_column :audiences, :relationship_state_and_pre_lapse_indicators, :text
    add_column :audiences, :motivational_drivers_and_messaging_framework, :text
    add_column :audiences, :strategic_reactivation_and_upgrade_cadence, :text
    add_column :audiences, :creative_and_imagery_rules, :text
    add_column :audiences, :risk_scoring_model, :text
    add_column :audiences, :prohibited_patterns, :text
    add_column :audiences, :success_indicators_and_macro_trends, :text
  end
end
