class CreateSubscriptionTiers < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_tiers, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :monthly_price_cents, null: false
      t.integer :annual_price_cents, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :subscription_tiers, :slug, unique: true
  end
end
