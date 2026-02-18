class MergeChannel < ApplicationCable::Channel
  def subscribed
    merge = find_merge
    if merge
      stream_from "merge:#{merge.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def find_merge
    project_ids = current_user.accounts
                               .joins(:projects)
                               .select("projects.id")
                               .pluck("projects.id")

    Merge.joins(:email_template)
         .where(email_templates: { project_id: project_ids })
         .find_by(id: params[:merge_id])
  end
end
