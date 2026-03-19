class AddElementSelectorToEmailTemplateSections < ActiveRecord::Migration[8.0]
  def change
    add_column :email_template_sections, :element_selector, :string
  end
end
