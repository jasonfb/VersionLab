class TemplateImportChannel < ApplicationCable::Channel
  def subscribed
    import = find_import
    if import
      stream_from "template_import:#{import.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def find_import
    project_ids = current_user.accounts
                               .joins(:projects)
                               .select("projects.id")
                               .pluck("projects.id")

    TemplateImport.joins(email_template: :project)
                  .where(email_templates: { project_id: project_ids })
                  .find_by(id: params[:import_id])
  end
end
