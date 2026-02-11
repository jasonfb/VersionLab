class CreateDataMigrations < ActiveRecord::Migration[8.1]
  def self.up
    create_table :data_migrations, id: false do |t|
      t.string :version
    end
  end

  def self.down
    drop_table :data_migrations
  end
end
