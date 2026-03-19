class RenameMergeToEmail < ActiveRecord::Migration[8.1]
  def up
    # Rename tables
    rename_table :merges, :emails
    rename_table :merge_audiences, :email_audiences
    rename_table :merge_versions, :email_versions
    rename_table :merge_version_variables, :email_version_variables

    # Rename FK columns
    rename_column :email_audiences, :merge_id, :email_id
    rename_column :email_versions, :merge_id, :email_id
    rename_column :email_version_variables, :merge_version_id, :email_version_id

    # Rename PostgreSQL enum types
    execute "ALTER TYPE merge_state RENAME TO email_state"
    execute "ALTER TYPE merge_version_state RENAME TO email_version_state"

    # Rename the 'merge' value in ai_log_call_type to 'email'
    execute "ALTER TYPE ai_log_call_type RENAME VALUE 'merge' TO 'email'"

    # Update polymorphic loggable_type references from 'Merge' to 'Email'
    execute "UPDATE ai_logs SET loggable_type = 'Email' WHERE loggable_type = 'Merge'"

  end

  def down
    execute "UPDATE ai_logs SET loggable_type = 'Merge' WHERE loggable_type = 'Email'"
    execute "ALTER TYPE ai_log_call_type RENAME VALUE 'email' TO 'merge'"
    execute "ALTER TYPE email_version_state RENAME TO merge_version_state"
    execute "ALTER TYPE email_state RENAME TO merge_state"

    rename_column :email_version_variables, :email_version_id, :merge_version_id
    rename_column :email_versions, :email_id, :merge_id
    rename_column :email_audiences, :email_id, :merge_id

    rename_table :email_version_variables, :merge_version_variables
    rename_table :email_versions, :merge_versions
    rename_table :email_audiences, :merge_audiences
    rename_table :emails, :merges
  end
end
