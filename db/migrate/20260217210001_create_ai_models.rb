class CreateAiModels < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_models, id: :uuid do |t|
      t.uuid :ai_service_id, null: false
      t.string :name, null: false
      t.string :api_identifier, null: false
      t.boolean :for_text, default: false, null: false
      t.boolean :for_image, default: false, null: false

      t.timestamps
    end

    add_index :ai_models, :ai_service_id
  end
end
