class AddHmidToVisits < ActiveRecord::Migration[8.1]
  def change
    add_column :visits, :hmid, :string
    add_index :visits, :hmid
  end
end
