class CreateAdFonts < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_fonts, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid :ad_id, null: false
      t.string :font_name, null: false
      t.string :postscript_name
      t.timestamps
    end

    add_index :ad_fonts, :ad_id
    add_foreign_key :ad_fonts, :ads
  end
end
