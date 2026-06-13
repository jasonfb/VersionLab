# This migration comes from helios_videos (originally 20250510000001)
class CreateHeliosVideosVideos < ActiveRecord::Migration[8.0]
  def change
    primary_key_type, foreign_key_type = primary_and_foreign_key_types

    create_table :helios_videos_videos, id: primary_key_type do |t|
      t.string :name
      t.string :key
      t.jsonb :playback_urls
      t.boolean :requires_signed_urls, default: false, null: false
      t.string :provider
      t.column :block_id, foreign_key_type

      t.timestamps
    end

    add_index :helios_videos_videos, :block_id
    add_index :helios_videos_videos, :key, unique: true
    add_index :helios_videos_videos, :provider
  end

  private

  def primary_and_foreign_key_types
    config = Rails.configuration.generators
    setting = config.options[config.orm][:primary_key_type]
    primary_key_type = setting || :primary_key
    foreign_key_type = setting || :bigint
    [ primary_key_type, foreign_key_type ]
  end
end
