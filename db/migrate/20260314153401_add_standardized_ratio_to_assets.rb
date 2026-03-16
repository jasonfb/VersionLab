class AddStandardizedRatioToAssets < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE asset_standardized_ratio AS ENUM (
        'hero_3_1',
        'banner_2_1',
        'widescreen_16_9',
        'square_1_1',
        'portrait_4_5'
      )
    SQL

    add_column :assets, :standardized_ratio, :asset_standardized_ratio
  end

  def down
    remove_column :assets, :standardized_ratio
    execute "DROP TYPE asset_standardized_ratio"
  end
end
