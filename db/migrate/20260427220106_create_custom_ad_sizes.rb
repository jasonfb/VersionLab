class CreateCustomAdSizes < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_ad_sizes, id: :uuid do |t|
      t.uuid :client_id, null: false
      t.string :label, null: false
      t.integer :width, null: false
      t.integer :height, null: false

      t.timestamps
    end

    add_foreign_key :custom_ad_sizes, :clients
    add_index :custom_ad_sizes, :client_id
    add_index :custom_ad_sizes, [:client_id, :width, :height], unique: true
  end
end
