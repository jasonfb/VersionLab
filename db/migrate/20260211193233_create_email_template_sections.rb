class CreateEmailTemplateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :email_template_sections, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :email_template_id, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :email_template_sections, [:email_template_id, :position]
  end
end
