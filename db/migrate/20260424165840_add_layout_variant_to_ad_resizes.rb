# frozen_string_literal: true

class AddLayoutVariantToAdResizes < ActiveRecord::Migration[8.1]
  def change
    add_column :ad_resizes, :layout_variant, :string, default: "center", null: false
  end
end
