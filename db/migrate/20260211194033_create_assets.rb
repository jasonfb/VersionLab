class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :assets, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.string :name
      t.integer :width
      t.integer :height

      t.timestamps
    end

    add_index :assets, :account_id
  end
end
