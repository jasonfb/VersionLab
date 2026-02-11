class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :uuid do |t|
      t.string :name

      t.timestamps
    end
  end
end
