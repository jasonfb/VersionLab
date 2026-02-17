class Api::MergesController < Api::BaseController
  before_action :set_project
  before_action :set_merge, only: [:update, :destroy]

  def index
    merges = Merge.joins(:email_template)
                  .where(email_templates: { project_id: @project.id })
                  .includes(:email_template, :audiences)
                  .order(updated_at: :desc)

    render json: merges.map { |m| merge_json(m) }
  end

  def create
    template = @project.email_templates.find(params[:merge][:email_template_id])
    merge = template.merges.build(state: "setup")

    if params[:merge][:audience_ids].present?
      audience_ids = params[:merge][:audience_ids]
      audiences = @project.audiences.where(id: audience_ids)
      merge.audiences = audiences
    end

    if merge.save
      render json: merge_json(merge), status: :created
    else
      render json: { errors: merge.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if params[:merge][:audience_ids]
      audience_ids = params[:merge][:audience_ids]
      audiences = @project.audiences.where(id: audience_ids)
      @merge.audiences = audiences
    end

    if @merge.save
      render json: merge_json(@merge)
    else
      render json: { errors: @merge.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @merge.destroy
    head :no_content
  end

  private

  def set_project
    @project = @current_account.projects.find(params[:project_id])
  end

  def set_merge
    @merge = Merge.joins(:email_template)
                  .where(email_templates: { project_id: @project.id })
                  .find(params[:id])
  end

  def merge_json(merge)
    {
      id: merge.id,
      email_template_id: merge.email_template_id,
      email_template_name: merge.email_template.name,
      state: merge.state,
      audience_ids: merge.audiences.map(&:id),
      audience_names: merge.audiences.map(&:name),
      updated_at: merge.updated_at
    }
  end
end
