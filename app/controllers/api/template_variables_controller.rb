class Api::TemplateVariablesController < Api::BaseController
  before_action :set_section
  before_action :set_variable, only: [:update, :destroy]

  def index
    variables = @section.template_variables.order(:position)
    render json: variables.map { |v| variable_json(v) }
  end

  def create
    next_position = (@section.template_variables.maximum(:position) || 0) + 1

    ActiveRecord::Base.transaction do
      @variable = @section.template_variables.build(
        id: params[:variable][:id],
        name: params[:variable][:name],
        variable_type: params[:variable][:variable_type] || "text",
        default_value: params[:variable][:default_value],
        slot_role: params[:variable][:slot_role].presence,
        word_count: params[:variable][:word_count].presence,
        position: next_position
      )
      @variable.save!
      @section.email_template.update!(raw_source_html: params[:raw_source_html]) if params[:raw_source_html].present?

      if params[:variable][:variable_type] == "image" &&
          params[:variable][:asset_id].present? &&
          params[:variable][:standardized_ratio].present?
        asset = @section.email_template.project.assets.find_by(id: params[:variable][:asset_id])
        asset&.update!(standardized_ratio: params[:variable][:standardized_ratio])
      end
    end

    render json: variable_json(@variable), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    if @variable.update(variable_params)
      render json: variable_json(@variable)
    else
      render json: { errors: @variable.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      @variable.destroy!
      @section.email_template.update!(raw_source_html: params[:raw_source_html]) if params[:raw_source_html].present?
    end
    head :no_content
  end

  private

  def set_section
    project = @current_account.projects.find(params[:project_id])
    template = project.email_templates.find(params[:email_template_id])
    @section = template.sections.find(params[:section_id])
  end

  def set_variable
    @variable = @section.template_variables.find(params[:id])
  end

  def variable_params
    params.require(:variable).permit(:name, :slot_role, :word_count, :default_value)
  end

  def variable_json(v)
    {
      id: v.id,
      name: v.name,
      variable_type: v.variable_type,
      default_value: v.default_value,
      slot_role: v.slot_role,
      word_count: v.word_count,
      position: v.position,
    }
  end
end
