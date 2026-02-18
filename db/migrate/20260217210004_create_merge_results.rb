class CreateMergeResults < ActiveRecord::Migration[8.1]
  def change
    create_table :merge_results, id: :uuid do |t|
      t.uuid :merge_id, null: false
      t.uuid :audience_id, null: false
      t.uuid :template_variable_id, null: false
      t.text :value, null: false

      t.timestamps
    end

    add_index :merge_results, [:merge_id, :audience_id]
    add_index :merge_results, [:merge_id, :audience_id, :template_variable_id], unique: true, name: "idx_merge_results_unique"
    add_foreign_key :merge_results, :merges
    add_foreign_key :merge_results, :audiences
    add_foreign_key :merge_results, :template_variables
  end
end
