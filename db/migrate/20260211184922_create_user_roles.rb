class CreateUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_roles, id: :uuid do |t|
      t.integer :user_id
      t.integer :role_id

      t.timestamps
    end
  end
end
