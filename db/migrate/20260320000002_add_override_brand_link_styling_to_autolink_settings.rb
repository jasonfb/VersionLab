class AddOverrideBrandLinkStylingToAutolinkSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :email_section_autolink_settings, :override_brand_link_styling, :boolean, default: false, null: false
  end
end
