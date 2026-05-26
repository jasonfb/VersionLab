# frozen_string_literal: true

class AddLayerOverridesToAds < ActiveRecord::Migration[8.1]
  def change
    add_column :ads, :layer_overrides, :jsonb, default: {}
  end
end
