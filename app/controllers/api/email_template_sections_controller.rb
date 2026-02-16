class Api::EmailTemplateSectionsController < Api::BaseController
  before_action :set_email_template

  def index
    sections = @email_template.sections.order(:position)
    render json: sections.map { |s|
      { id: s.id, position: s.position, created_at: s.created_at }
    }
  end

  def create
    next_position = (@email_template.sections.maximum(:position) || 0) + 1
    section = @email_template.sections.build(position: next_position)

    if section.save
      render json: { id: section.id, position: section.position }, status: :created
    else
      render json: { errors: section.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    section = @email_template.sections.find(params[:id])
    section.destroy
    reorder_sections
    if params[:raw_source_html].present?
      @email_template.update!(raw_source_html: params[:raw_source_html])
    end
    head :no_content
  end

  private

  def set_email_template
    project = @current_account.projects.find(params[:project_id])
    @email_template = project.email_templates.find(params[:email_template_id])
  end

  def reorder_sections
    @email_template.sections.order(:position).each_with_index do |s, i|
      s.update_column(:position, i + 1)
    end
  end
end
