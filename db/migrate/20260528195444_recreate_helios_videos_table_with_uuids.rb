class RecreateHeliosVideosTableWithUuids < ActiveRecord::Migration[8.1]
  def up
    drop_table :helios_videos_videos, if_exists: true

    create_table :helios_videos_videos, id: :uuid do |t|
      t.string :name
      t.string :key
      t.jsonb :playback_urls
      t.boolean :requires_signed_urls, default: false, null: false
      t.string :provider
      t.uuid :block_id

      t.timestamps
    end

    add_index :helios_videos_videos, :block_id
    add_index :helios_videos_videos, :key, unique: true
    add_index :helios_videos_videos, :provider
  end

  def down
    drop_table :helios_videos_videos, if_exists: true
  end
end
