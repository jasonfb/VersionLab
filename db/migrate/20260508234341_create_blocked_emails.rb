class CreateBlockedEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :blocked_emails, id: :uuid do |t|
      t.string :email, null: false
      t.string :source, null: false
      t.timestamps
    end

    add_index :blocked_emails, :email
    add_index :blocked_emails, :created_at
  end
end
