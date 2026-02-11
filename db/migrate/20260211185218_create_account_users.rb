class CreateAccountUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :account_users, id: :uuid do |t|
      t.uuid :account_id
      t.uuid :user_id
      t.boolean :is_owner

      t.timestamps
    end
  end
end
