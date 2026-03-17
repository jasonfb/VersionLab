class RenameProjectsToClients < ActiveRecord::Migration[8.1]
  def change
    rename_table :projects, :clients

    rename_column :assets, :project_id, :client_id
    rename_column :audiences, :project_id, :client_id
    rename_column :email_templates, :project_id, :client_id
  end
end
