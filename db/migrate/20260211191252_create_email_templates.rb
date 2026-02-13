class CreateEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :email_templates, id: :uuid do |t|
      t.uuid :account_id
      t.string :name
      t.text :raw_source_html

      t.timestamps
    end
  end
end
