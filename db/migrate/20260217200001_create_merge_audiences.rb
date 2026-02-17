class CreateMergeAudiences < ActiveRecord::Migration[8.1]
  def change
    create_table :merge_audiences, id: :uuid do |t|
      t.uuid :merge_id, null: false
      t.uuid :audience_id, null: false

      t.timestamps
    end
  end
end
