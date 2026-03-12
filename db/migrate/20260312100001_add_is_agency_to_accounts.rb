class AddIsAgencyToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :is_agency, :boolean, default: false, null: false
  end
end
