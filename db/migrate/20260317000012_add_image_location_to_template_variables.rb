class AddImageLocationToTemplateVariables < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE TYPE template_variable_image_location AS ENUM ('hero', 'banner', 'sidebar', 'inline', 'footer')"
    add_column :template_variables, :image_location, :template_variable_image_location
  end

  def down
    remove_column :template_variables, :image_location
    execute "DROP TYPE template_variable_image_location"
  end
end
