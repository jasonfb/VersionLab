class CreateAdAudiences < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_audiences, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid :ad_id, null: false
      t.uuid :audience_id, null: false
      t.timestamps
    end

    add_index :ad_audiences, [ :ad_id, :audience_id ], unique: true
    add_foreign_key :ad_audiences, :ads
    add_foreign_key :ad_audiences, :audiences
  end
end
