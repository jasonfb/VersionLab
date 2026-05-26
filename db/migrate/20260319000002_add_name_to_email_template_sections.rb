# frozen_string_literal: true

class AddNameToEmailTemplateSections < ActiveRecord::Migration[8.0]
  def change
    add_column :email_template_sections, :name, :string
  end
end
