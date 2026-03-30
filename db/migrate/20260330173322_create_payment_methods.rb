class CreatePaymentMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_methods, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.string :stripe_payment_method_id, null: false
      t.string :card_brand
      t.string :card_last4
      t.integer :card_exp_month
      t.integer :card_exp_year
      t.boolean :is_default, default: false, null: false
      t.timestamps
    end

    add_index :payment_methods, :account_id
    add_index :payment_methods, :stripe_payment_method_id, unique: true
  end
end
