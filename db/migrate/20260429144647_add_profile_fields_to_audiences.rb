class AddProfileFieldsToAudiences < ActiveRecord::Migration[8.1]
  def change
    change_table :audiences, bulk: true do |t|
      # Single-value profile fields
      t.string :client_url
      t.string :industry
      t.string :industry_other
      t.string :interaction_recency
      t.string :interaction_recency_other
      t.string :purchase_cadence
      t.string :purchase_cadence_other
      t.string :relationship_status
      t.string :primary_action
      t.string :primary_action_other
      t.string :order_value_band
      t.string :order_value_band_other
      t.string :promotion_sensitivity
      t.string :promotion_sensitivity_other
      t.string :communication_frequency
      t.string :communication_frequency_other
      t.string :product_visuals_impact

      # Text fields
      t.text :general_insights
      t.text :product_categories_themes

      # Array fields (multiselect)
      t.text :supporting_sites, array: true, default: []
      t.text :outcomes_that_matter, array: true, default: []
      t.text :top_purchase_drivers, array: true, default: []
      t.text :action_prevention_factors, array: true, default: []
      t.text :checkout_friction_points, array: true, default: []
      t.text :communication_channels, array: true, default: []
      t.text :lifecycle_messages, array: true, default: []

      # "Other" text for multiselect fields
      t.string :outcomes_that_matter_other
      t.string :top_purchase_drivers_other
      t.string :action_prevention_factors_other
      t.string :checkout_friction_points_other
      t.string :communication_channels_other
      t.string :lifecycle_messages_other

      # AI summary state
      t.datetime :ai_summary_generated_at
    end

    execute "ALTER TABLE audiences ADD COLUMN ai_summary_state campaign_ai_summary_state NOT NULL DEFAULT 'idle'"
  end
end
