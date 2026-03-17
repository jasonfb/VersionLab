class AddFieldsToCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_enum "campaign_status", [ "draft", "active", "completed", "archived" ]
    create_enum "campaign_ai_summary_state", [ "idle", "generating", "generated", "failed" ]

    add_column :campaigns, :description, :text
    add_column :campaigns, :goals, :text
    add_column :campaigns, :start_date, :date
    add_column :campaigns, :end_date, :date
    add_column :campaigns, :status, :enum, enum_type: "campaign_status", default: "draft", null: false
    add_column :campaigns, :ai_summary, :text
    add_column :campaigns, :ai_summary_state, :enum, enum_type: "campaign_ai_summary_state", default: "idle", null: false
    add_column :campaigns, :ai_summary_generated_at, :datetime
  end
end
