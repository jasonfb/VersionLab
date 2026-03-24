class EmailChannel < ApplicationCable::Channel
  def subscribed
    email = find_email
    if email
      stream_from "email:#{email.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def find_email
    client_ids = current_user.accounts
                              .joins(:clients)
                              .select("clients.id")
                              .pluck("clients.id")

    Email.joins(:email_template)
         .where(email_templates: { client_id: client_ids })
         .find_by(id: params[:email_id])
  end
end
