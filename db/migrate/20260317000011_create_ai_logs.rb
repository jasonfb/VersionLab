class CreateAiLogs < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE TYPE ai_log_call_type AS ENUM ('merge', 'campaign_summary')"

    create_table :ai_logs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :account_id, null: false
      t.column :call_type, :ai_log_call_type, null: false
      t.uuid :ai_service_id
      t.uuid :ai_model_id
      t.string :loggable_type
      t.uuid :loggable_id
      t.text :prompt
      t.text :response
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.timestamps
    end

    add_index :ai_logs, :account_id
    add_index :ai_logs, [ :loggable_type, :loggable_id ], name: "idx_ai_logs_on_loggable"
    add_index :ai_logs, :created_at
    add_foreign_key :ai_logs, :accounts
  end

  def down
    drop_table :ai_logs
    execute "DROP TYPE ai_log_call_type"
  end
end
