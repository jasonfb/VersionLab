class AddAudienceSummaryCallType < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TYPE ai_log_call_type ADD VALUE IF NOT EXISTS 'audience_summary'"
  end

  def down
    # PostgreSQL does not support removing enum values
  end
end
