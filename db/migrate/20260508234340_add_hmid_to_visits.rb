class AddHmidToVisits < ActiveRecord::Migration[8.1]
  def change
    add_column :utm_visits, :hmid, :string
    add_index :utm_visits, :hmid
  end
end
