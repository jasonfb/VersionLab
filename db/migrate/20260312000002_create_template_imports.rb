class CreateTemplateImports < ActiveRecord::Migration[8.1]
  def up
    create_enum :template_import_type, %w[bundled external]
    create_enum :template_import_state, %w[pending processing completed failed]

    create_table :template_imports, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :email_template_id, null: false
      t.enum :import_type, enum_type: :template_import_type, null: false
      t.enum :state, enum_type: :template_import_state, null: false, default: "pending"
      t.text :warnings
      t.text :error_message
      t.timestamps
    end

    add_index :template_imports, :email_template_id
    add_foreign_key :template_imports, :email_templates
  end

  def down
    drop_table :template_imports
    execute "DROP TYPE template_import_type"
    execute "DROP TYPE template_import_state"
  end
end
