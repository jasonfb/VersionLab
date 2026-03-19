class Api::EmailTemplateSectionsController < Api::BaseController
  before_action :set_email_template

  def index
    sections = @email_template.sections.order(:position)
    render json: sections.map { |s| section_json(s) }
  end

  def create
    parent_id = params.dig(:section, :parent_id).presence
    next_position = (@email_template.sections.where(parent_id: parent_id).maximum(:position) || 0) + 1

    name = params.dig(:section, :name).presence
    if name.nil? && parent_id.present?
      parent = @email_template.sections.find(parent_id)
      letter = ('A'..'Z').to_a[next_position - 1] || next_position.to_s
      name = "#{parent.position}#{letter}"
    end

    section = @email_template.sections.build(
      position: next_position,
      parent_id: parent_id,
      element_selector: params.dig(:section, :element_selector),
      name: name
    )

    if section.save
      render json: section_json(section), status: :created
    else
      render json: { errors: section.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    section = @email_template.sections.find(params[:id])
    if section.update(section_update_params)
      render json: section_json(section)
    else
      render json: { errors: section.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    section = @email_template.sections.find(params[:id])
    parent_id = section.parent_id
    section.destroy # cascades to subsections via dependent: :destroy
    reorder_sections(parent_id)
    if params[:raw_source_html].present?
      @email_template.update!(raw_source_html: params[:raw_source_html])
    end
    head :no_content
  end

  private

  def section_json(section)
    {
      id: section.id,
      position: section.position,
      parent_id: section.parent_id,
      element_selector: section.element_selector,
      name: section.name,
    }
  end

  def section_update_params
    params.require(:section).permit(:element_selector, :name)
  end

  def set_email_template
    client = @current_account.clients.find(params[:client_id])
    @email_template = client.email_templates.find(params[:email_template_id])
  end

  def reorder_sections(parent_id)
    @email_template.sections.where(parent_id: parent_id).order(:position).each_with_index do |s, i|
      s.update_column(:position, i + 1)
    end
  end
end
