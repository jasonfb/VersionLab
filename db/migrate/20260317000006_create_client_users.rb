class CreateClientUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :client_users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :client_id, null: false
      t.uuid :user_id, null: false
      t.timestamps
    end

    add_index :client_users, [:client_id, :user_id], unique: true
  end
end
