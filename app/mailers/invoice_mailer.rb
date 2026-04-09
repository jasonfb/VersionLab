class InvoiceMailer < ApplicationMailer
  def issued(invoice)
    @invoice = invoice
    @account = invoice.account
    @line_items = invoice.line_items.to_a

    recipient = @account.users.joins(:account_users)
      .where(account_users: { account: @account })
      .first&.email

    return unless recipient

    mail(
      to: recipient,
      subject: "VersionLab invoice #{invoice.invoice_number} — $#{format('%.2f', invoice.total_cents / 100.0)}"
    )
  end
end
