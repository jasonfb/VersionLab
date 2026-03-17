class CreateCampaignDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :campaign_documents, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :campaign_id, null: false
      t.string :display_name, null: false
      t.text :content_text
      t.timestamps
    end

    add_index :campaign_documents, :campaign_id
    add_foreign_key :campaign_documents, :campaigns
  end
end
