class AddRoles < ActiveRecord::Migration[8.1]
  def change
    Role.create(name: "admin", label: "Admin")
    Role.create(name: "user", label: "User")
    Role.create(name: "superadmin", label: "Superadmin")
  end
end
