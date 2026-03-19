class AddEmailDocuments < ActiveRecord::Migration[8.1]
  def up
    # Add email_summary call type to ai_log_call_type enum
    execute "ALTER TYPE ai_log_call_type ADD VALUE IF NOT EXISTS 'email_summary'"

    # Add AI summary fields to emails
    execute "ALTER TABLE emails ADD COLUMN ai_summary text"
    execute "ALTER TABLE emails ADD COLUMN ai_summary_state campaign_ai_summary_state NOT NULL DEFAULT 'idle'"
    execute "ALTER TABLE emails ADD COLUMN ai_summary_generated_at timestamp"

    # Create email_documents table
    create_table :email_documents, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :email_id, null: false
      t.string :display_name, null: false
      t.text :content_text
      t.timestamps
    end

    add_index :email_documents, :email_id
    add_foreign_key :email_documents, :emails
  end

  def down
    remove_foreign_key :email_documents, :emails
    drop_table :email_documents

    execute "ALTER TABLE emails DROP COLUMN ai_summary_generated_at"
    execute "ALTER TABLE emails DROP COLUMN ai_summary_state"
    execute "ALTER TABLE emails DROP COLUMN ai_summary"

    # Note: PostgreSQL does not support removing enum values; email_summary remains in ai_log_call_type
  end
end
