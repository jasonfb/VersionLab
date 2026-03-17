class AddClientCampaignContextToMerges < ActiveRecord::Migration[8.1]
  def change
    add_column :merges, :client_id, :uuid
    add_column :merges, :campaign_id, :uuid
    add_column :merges, :context, :text

    # Backfill client_id from the associated email_template
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE merges
          SET client_id = email_templates.client_id
          FROM email_templates
          WHERE merges.email_template_id = email_templates.id
        SQL
      end
    end

    change_column_null :merges, :client_id, false

    add_index :merges, :client_id
    add_index :merges, :campaign_id
    add_foreign_key :merges, :clients
    add_foreign_key :merges, :campaigns
  end
end
