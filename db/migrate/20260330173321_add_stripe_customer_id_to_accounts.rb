class AddStripeCustomerIdToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :stripe_customer_id, :string
    add_index :accounts, :stripe_customer_id, unique: true
  end
end
