class MigrateAssetsToProjects < ActiveRecord::Migration[8.1]
  def up
    # Step 1: add nullable project_id to assets
    add_column :assets, :project_id, :uuid
    add_index :assets, :project_id

    # Step 2: for each account, create a hidden "default" project and move assets there
    execute <<~SQL
      INSERT INTO projects (id, account_id, name, hidden, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        a.id,
        a.name,
        TRUE,
        NOW(),
        NOW()
      FROM accounts a
    SQL

    # Step 3: assign each asset to the hidden project of its account
    execute <<~SQL
      UPDATE assets
      SET project_id = p.id
      FROM projects p
      WHERE p.account_id = assets.account_id
        AND p.hidden = TRUE
    SQL

    # Step 4: make project_id not null and add foreign key
    change_column_null :assets, :project_id, false
    add_foreign_key :assets, :projects

    # Step 5: remove account_id from assets
    remove_foreign_key :assets, :accounts, if_exists: true
    remove_index :assets, :account_id, if_exists: true
    remove_column :assets, :account_id
  end

  def down
    add_column :assets, :account_id, :uuid
    add_index :assets, :account_id

    execute <<~SQL
      UPDATE assets
      SET account_id = p.account_id
      FROM projects p
      WHERE p.id = assets.project_id
    SQL

    change_column_null :assets, :account_id, false

    remove_foreign_key :assets, :projects, if_exists: true
    remove_index :assets, :project_id, if_exists: true
    remove_column :assets, :project_id

    execute "DELETE FROM projects WHERE hidden = TRUE"
  end
end
