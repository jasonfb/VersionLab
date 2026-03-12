class FixUserRolesForeignKeyTypes < ActiveRecord::Migration[8.1]
  def up
    # user_roles was created with integer FKs but users/roles use UUID PKs
    change_column :user_roles, :user_id, :uuid, using: "user_id::text::uuid"
    change_column :user_roles, :role_id, :uuid, using: "role_id::text::uuid"
  end

  def down
    change_column :user_roles, :user_id, :integer, using: "user_id::text::integer"
    change_column :user_roles, :role_id, :integer, using: "role_id::text::integer"
  end
end
