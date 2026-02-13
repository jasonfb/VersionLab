class CreateTemplateVariables < ActiveRecord::Migration[8.1]
  def change
    create_table :template_variables, id: :uuid do |t|
      t.uuid :email_template_section_id, null: false
      t.string :name, null: false
      t.string :variable_type, null: false, default: "text"
      t.text :default_value, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :template_variables, [:email_template_section_id, :position]
  end
end
