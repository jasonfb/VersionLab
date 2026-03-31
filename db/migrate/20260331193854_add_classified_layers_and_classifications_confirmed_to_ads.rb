class AddClassifiedLayersAndClassificationsConfirmedToAds < ActiveRecord::Migration[8.1]
  def change
    add_column :ads, :classified_layers, :jsonb, default: [], null: false
    add_column :ads, :classifications_confirmed, :boolean, default: false, null: false
  end
end
