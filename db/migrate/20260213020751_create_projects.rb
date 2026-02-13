class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.string :name, null: false

      t.timestamps
    end
  end
end
