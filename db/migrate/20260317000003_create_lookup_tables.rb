class CreateLookupTables < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_types, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :industries, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :primary_audiences, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :tone_rules, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :geographies, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
