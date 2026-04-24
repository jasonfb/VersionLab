class ChangeCustomerChoosesAiDefaultToFalse < ActiveRecord::Migration[8.1]
  def change
    change_column_default :accounts, :customer_chooses_ai, from: true, to: false
  end
end
