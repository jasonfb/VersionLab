class AddFolderToAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :assets, :folder, :string
  end
end
