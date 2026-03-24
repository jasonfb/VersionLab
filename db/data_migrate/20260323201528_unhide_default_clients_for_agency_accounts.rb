class UnhideDefaultClientsForAgencyAccounts < ActiveRecord::Migration[8.1]
  def up
    Account.where(is_agency: true).find_each do |account|
      client = account.clients.find_by(hidden: true)
      next unless client
      client.update!(hidden: false, name: account.name)
    end
  end

  def down
    # No-op: cannot reliably determine which clients were originally hidden
  end
end
