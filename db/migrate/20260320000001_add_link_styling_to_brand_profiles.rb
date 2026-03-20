class AddLinkStylingToBrandProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :brand_profiles, :link_color, :string
    add_column :brand_profiles, :underline_links, :boolean, default: false, null: false
    add_column :brand_profiles, :italic_links, :boolean, default: false, null: false
    add_column :brand_profiles, :bold_links, :boolean, default: false, null: false
  end
end
