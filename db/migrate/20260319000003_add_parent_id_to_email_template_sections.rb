class AddParentIdToEmailTemplateSections < ActiveRecord::Migration[8.0]
  def change
    add_column :email_template_sections, :parent_id, :uuid, null: true
  end
end
