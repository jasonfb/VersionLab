class RefactorMergesToVersions < ActiveRecord::Migration[8.1]
  def up
    # Blow away all existing merge data
    execute "TRUNCATE TABLE merge_results, merge_audiences, merges RESTART IDENTITY CASCADE"

    # Create postgres enum types
    execute "CREATE TYPE merge_state AS ENUM ('setup', 'pending', 'merged', 'regenerating')"
    execute "CREATE TYPE merge_version_state AS ENUM ('generating', 'active', 'rejected')"

    # Convert merges.state from string to postgres enum
    remove_column :merges, :state
    execute "ALTER TABLE merges ADD COLUMN state merge_state NOT NULL DEFAULT 'setup'"

    # Drop merge_results
    drop_table :merge_results

    # Create merge_versions
    create_table :merge_versions, id: :uuid do |t|
      t.uuid :merge_id, null: false
      t.uuid :audience_id, null: false
      t.integer :version_number, null: false, default: 1
      t.column :state, :merge_version_state, null: false, default: "generating"
      t.text :rejection_comment
      t.uuid :ai_service_id, null: false
      t.uuid :ai_model_id, null: false
      t.timestamps
    end

    add_index :merge_versions, [:merge_id, :audience_id, :version_number],
              unique: true, name: "idx_merge_versions_unique"
    add_index :merge_versions, [:merge_id, :audience_id],
              name: "idx_merge_versions_on_merge_and_audience"

    # Create merge_version_variables
    create_table :merge_version_variables, id: :uuid do |t|
      t.uuid :merge_version_id, null: false
      t.uuid :template_variable_id, null: false
      t.text :value, null: false
      t.timestamps
    end

    add_index :merge_version_variables, [:merge_version_id, :template_variable_id],
              unique: true, name: "idx_merge_version_variables_unique"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
