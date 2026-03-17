class AddRolesToAccountUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :account_users, :is_admin, :boolean, default: false, null: false
    add_column :account_users, :is_billing_admin, :boolean, default: false, null: false
  end
end
