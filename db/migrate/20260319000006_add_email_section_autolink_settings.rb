class AddEmailSectionAutolinkSettings < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE TYPE autolink_mode AS ENUM ('none', 'link_relevant_text')"
    execute "CREATE TYPE autolink_link_mode AS ENUM ('user_url', 'ai_decide')"

    create_table :email_section_autolink_settings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :email_id, null: false
      t.uuid :email_template_section_id, null: false
      t.enum :autolink_mode, enum_type: "autolink_mode", null: false, default: "none"
      t.enum :link_mode, enum_type: "autolink_link_mode"
      t.string :url
      t.text :group_purpose
      t.string :link_color
      t.boolean :underline_links, default: false, null: false
      t.boolean :italic_links, default: false, null: false
      t.boolean :bold_links, default: false, null: false
      t.timestamps

      t.index [ :email_id, :email_template_section_id ], unique: true
    end
  end

  def down
    drop_table :email_section_autolink_settings
    execute "DROP TYPE autolink_link_mode"
    execute "DROP TYPE autolink_mode"
  end
end
