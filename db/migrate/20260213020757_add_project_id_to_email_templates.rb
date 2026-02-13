class AddProjectIdToEmailTemplates < ActiveRecord::Migration[8.1]
  def up
    add_column :email_templates, :project_id, :uuid

    # Migrate existing templates: create a default project per account
    execute <<~SQL
      INSERT INTO projects (id, account_id, name, created_at, updated_at)
      SELECT DISTINCT
        gen_random_uuid(),
        account_id,
        'Default Project',
        NOW(),
        NOW()
      FROM email_templates
      WHERE account_id IS NOT NULL
        AND account_id NOT IN (SELECT account_id FROM projects)
    SQL

    execute <<~SQL
      UPDATE email_templates
      SET project_id = projects.id
      FROM projects
      WHERE email_templates.account_id = projects.account_id
    SQL

    change_column_null :email_templates, :project_id, false
    remove_column :email_templates, :account_id
  end

  def down
    add_column :email_templates, :account_id, :uuid

    execute <<~SQL
      UPDATE email_templates
      SET account_id = projects.account_id
      FROM projects
      WHERE email_templates.project_id = projects.id
    SQL

    remove_column :email_templates, :project_id
  end
end
