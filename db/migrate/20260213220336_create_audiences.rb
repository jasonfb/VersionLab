class CreateAudiences < ActiveRecord::Migration[8.1]
  def change
    create_table :audiences, id: :uuid do |t|
      t.uuid :project_id, null: false
      t.string :name, null: false
      t.text :details

      t.timestamps
    end
  end
end
