class AddAdResizeIdToAdVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :ad_versions, :ad_resize_id, :uuid

    remove_index :ad_versions, [ :ad_id, :audience_id, :version_number ]
    remove_index :ad_versions, [ :ad_id, :audience_id ]

    add_index :ad_versions, [ :ad_id, :ad_resize_id, :audience_id, :version_number ],
              unique: true,
              name: "idx_ad_versions_unique_per_resize_audience"
    add_index :ad_versions, [ :ad_id, :ad_resize_id, :audience_id ],
              name: "idx_ad_versions_on_ad_resize_audience"

    add_foreign_key :ad_versions, :ad_resizes
  end
end
