class AddTokenCycleAndFinalBilledToSubscriptions < ActiveRecord::Migration[8.1]
  def up
    add_column :subscriptions, :token_cycle_started_on, :date
    add_column :subscriptions, :final_billed_at, :datetime

    # Backfill existing subs: anchor token cycle to start_date.
    execute <<~SQL
      UPDATE subscriptions
         SET token_cycle_started_on = start_date
       WHERE token_cycle_started_on IS NULL
    SQL

    change_column_null :subscriptions, :token_cycle_started_on, false
  end

  def down
    remove_column :subscriptions, :token_cycle_started_on
    remove_column :subscriptions, :final_billed_at
  end
end
