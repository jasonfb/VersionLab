class CreateMerges < ActiveRecord::Migration[8.1]
  def change
    create_table :merges, id: :uuid do |t|
      t.uuid :email_template_id, null: false
      t.string :state, null: false, default: "setup"

      t.timestamps
    end
  end
end
