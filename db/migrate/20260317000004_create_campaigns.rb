class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :client_id, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :campaigns, :client_id
    add_foreign_key :campaigns, :clients
  end
end
