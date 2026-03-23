class AddAdsEnums < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "CREATE TYPE ad_state AS ENUM ('setup', 'pending', 'merged', 'regenerating')"
    execute "CREATE TYPE ad_version_state AS ENUM ('generating', 'active', 'rejected')"
    execute "CREATE TYPE ad_background_type AS ENUM ('solid_color', 'image')"
    execute "CREATE TYPE ad_overlay_type AS ENUM ('solid', 'gradient')"
    execute "CREATE TYPE ad_versioning_mode AS ENUM ('retain_existing', 'version_ads')"
    execute "CREATE TYPE ad_output_format AS ENUM ('png', 'jpg')"
    execute "ALTER TYPE ai_log_call_type ADD VALUE IF NOT EXISTS 'ad'"
  end

  def down
    execute "DROP TYPE IF EXISTS ad_state"
    execute "DROP TYPE IF EXISTS ad_version_state"
    execute "DROP TYPE IF EXISTS ad_background_type"
    execute "DROP TYPE IF EXISTS ad_overlay_type"
    execute "DROP TYPE IF EXISTS ad_versioning_mode"
    execute "DROP TYPE IF EXISTS ad_output_format"
  end
end
