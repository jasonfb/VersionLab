# frozen_string_literal: true

class CreateUniversalTrackManagerTables < ActiveRecord::Migration[8.1]
  def self.up
    ActiveRecord::Base.transaction do

      create_table :utm_browsers do |t|
        # this table gets automatically populated by inbound traffic
        t.string :name, limit: 255
        t.timestamps
      end

      add_index :utm_browsers, :name

      create_table :utm_campaigns do |t|
        # this table gets automatically populated by inbound traffic
          t.string :utm_source, limit:256
          t.string :utm_medium, limit:256
          t.string :utm_campaign, limit:256
          t.string :utm_content, limit:256
          t.string :utm_term, limit:256

        t.string :sha1, limit: 40
        t.boolean :gclid_present
        t.timestamps
      end

      add_index :utm_campaigns, :sha1

      create_table :utm_visits do |t|
        t.datetime :first_pageload
        t.datetime :last_pageload
        t.integer :original_visit_id
        t.integer :campaign_id
        t.integer :browser_id
        t.string :ip_v4_address, limit: 15

        t.integer :viewport_width
        t.integer :viewport_height
        t.integer :count, default: 1
        t.timestamps
      end
    end
  end

  def self.down
    ActiveRecord::Base.transaction do
      drop_table :utm_browsers
      drop_table :utm_visits
      drop_table :utm_campaigns
    end
  end
end
