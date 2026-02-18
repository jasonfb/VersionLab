class CreateAiServices < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_services, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :ai_services, :slug, unique: true
  end
end
