class CreateCampaignLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :campaign_links, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :campaign_id, null: false
      t.text :url, null: false
      t.string :title
      t.text :link_description
      t.text :image_url
      t.datetime :fetched_at
      t.timestamps
    end

    add_index :campaign_links, :campaign_id
    add_foreign_key :campaign_links, :campaigns
  end
end
