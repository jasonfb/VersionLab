class FixUniversalTrackManagerTableNames < ActiveRecord::Migration[8.1]
  def up
    # Production had a partial install of universal-track-manager 0.8 which created
    # `browsers` and `visits` tables, but `campaigns` failed because VersionLab
    # already has its own `campaigns` table. Now that UTM 0.9 supports table_prefix,
    # we rename existing tables and create the missing one.

    if table_exists?(:browsers) && !table_exists?(:utm_browsers)
      rename_table :browsers, :utm_browsers
    end

    if table_exists?(:visits) && !table_exists?(:utm_visits)
      rename_table :visits, :utm_visits
    end

    unless table_exists?(:utm_campaigns)
      create_table :utm_campaigns do |t|
        t.string :utm_source, limit: 256
        t.string :utm_medium, limit: 256
        t.string :utm_campaign, limit: 256
        t.string :utm_content, limit: 256
        t.string :utm_term, limit: 256
        t.string :sha1, limit: 40
        t.boolean :gclid_present
        t.timestamps
      end

      add_index :utm_campaigns, :sha1
    end

    unless column_exists?(:utm_visits, :hmid)
      add_column :utm_visits, :hmid, :string
      add_index :utm_visits, :hmid
    end
  end

  def down
    if table_exists?(:utm_browsers) && !table_exists?(:browsers)
      rename_table :utm_browsers, :browsers
    end

    if table_exists?(:utm_visits) && !table_exists?(:visits)
      remove_index :utm_visits, :hmid, if_exists: true
      remove_column :utm_visits, :hmid, if_exists: true
      rename_table :utm_visits, :visits
    end

    drop_table :utm_campaigns, if_exists: true
  end
end
