class CreateBrandProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :brand_profiles, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :client_id, null: false
      t.string :organization_name
      t.string :primary_domain
      t.uuid :organization_type_id
      t.uuid :industry_id
      t.text :mission_statement
      t.text :core_programs, array: true, default: []
      t.text :approved_vocabulary, array: true, default: []
      t.text :blocked_vocabulary, array: true, default: []
      t.text :color_palette, array: true, default: []
      t.timestamps
    end

    add_index :brand_profiles, :client_id, unique: true
    add_foreign_key :brand_profiles, :clients
    add_foreign_key :brand_profiles, :organization_types
    add_foreign_key :brand_profiles, :industries

    create_table :brand_profile_primary_audiences, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :brand_profile_id, null: false
      t.uuid :primary_audience_id, null: false
      t.timestamps
    end

    add_index :brand_profile_primary_audiences, [:brand_profile_id, :primary_audience_id], unique: true, name: "idx_bp_primary_audiences"
    add_foreign_key :brand_profile_primary_audiences, :brand_profiles
    add_foreign_key :brand_profile_primary_audiences, :primary_audiences

    create_table :brand_profile_tone_rules, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :brand_profile_id, null: false
      t.uuid :tone_rule_id, null: false
      t.timestamps
    end

    add_index :brand_profile_tone_rules, [:brand_profile_id, :tone_rule_id], unique: true, name: "idx_bp_tone_rules"
    add_foreign_key :brand_profile_tone_rules, :brand_profiles
    add_foreign_key :brand_profile_tone_rules, :tone_rules

    create_table :brand_profile_geographies, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :brand_profile_id, null: false
      t.uuid :geography_id, null: false
      t.timestamps
    end

    add_index :brand_profile_geographies, [:brand_profile_id, :geography_id], unique: true, name: "idx_bp_geographies"
    add_foreign_key :brand_profile_geographies, :brand_profiles
    add_foreign_key :brand_profile_geographies, :geographies
  end
end
