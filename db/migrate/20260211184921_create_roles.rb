class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles, id: :uuid do |t|
      t.string :name
      t.string :label

      t.timestamps
    end
  end
end
