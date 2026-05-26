# This migration comes from helios_videos (originally 20250510000001)
class CreateHeliosVideosVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :helios_videos_videos do |t|
      t.string :name
      t.string :key
      t.jsonb :playback_urls
      t.boolean :requires_signed_urls, default: false, null: false
      t.string :provider
      t.integer :block_id

      t.timestamps
    end

    add_index :helios_videos_videos, :block_id
    add_index :helios_videos_videos, :key, unique: true
    add_index :helios_videos_videos, :provider
  end
end
