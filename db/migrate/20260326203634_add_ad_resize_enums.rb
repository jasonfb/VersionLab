class AddAdResizeEnums < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "CREATE TYPE ad_resize_state AS ENUM ('pending', 'resized', 'failed')"
    execute "ALTER TYPE ad_state ADD VALUE IF NOT EXISTS 'resizing'"
  end

  def down
    execute "DROP TYPE IF EXISTS ad_resize_state"
    # Cannot remove individual enum values in PostgreSQL
  end
end
