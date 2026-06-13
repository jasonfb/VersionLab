class RecreateHeliosPressTablesWithUuids < ActiveRecord::Migration[8.1]
  def up
    drop_table :helios_press_block_images, if_exists: true
    drop_table :helios_press_blocks, if_exists: true
    drop_table :helios_press_posts, if_exists: true

    # Clean up any orphaned action_text_rich_texts for old integer-PK blocks
    execute <<~SQL
      DELETE FROM action_text_rich_texts
      WHERE record_type = 'Helios::Press::Block'
    SQL

    create_table :helios_press_posts, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :keywords
      t.boolean :published, default: false, null: false
      t.string :external_id

      t.timestamps
    end

    add_index :helios_press_posts, :slug, unique: true
    add_index :helios_press_posts, :external_id, unique: true
    add_index :helios_press_posts, :published

    create_table :helios_press_blocks, id: :uuid do |t|
      t.references :post, null: false, foreign_key: { to_table: :helios_press_posts }, type: :uuid
      t.string :block_type, null: false
      t.integer :position, null: false
      t.integer :columns, default: 3

      t.timestamps
    end

    add_index :helios_press_blocks, [ :post_id, :position ]

    create_table :helios_press_block_images, id: :uuid do |t|
      t.references :block, null: false, foreign_key: { to_table: :helios_press_blocks }, type: :uuid
      t.integer :position, null: false
      t.text :caption
      t.string :reference_key

      t.timestamps
    end

    add_index :helios_press_block_images, [ :block_id, :position ]
    add_index :helios_press_block_images, [ :block_id, :reference_key ], unique: true
  end

  def down
    drop_table :helios_press_block_images, if_exists: true
    drop_table :helios_press_blocks, if_exists: true
    drop_table :helios_press_posts, if_exists: true
  end
end
