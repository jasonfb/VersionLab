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
    project_ids = current_user.accounts
                               .joins(:projects)
                               .select("projects.id")
                               .pluck("projects.id")

    Email.joins(:email_template)
         .where(email_templates: { project_id: project_ids })
         .find_by(id: params[:email_id])
  end
end
