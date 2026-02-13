class Api::EmailTemplatesController < Api::BaseController
  before_action :set_email_template, only: [:show, :update, :destroy]

  def index
    templates = @current_account.email_templates.order(updated_at: :desc)
    render json: templates.map { |t|
      { id: t.id, name: t.name, updated_at: t.updated_at }
    }
  end

  def show
    render json: {
      id: @email_template.id,
      name: @email_template.name,
      raw_source_html: @email_template.raw_source_html,
      updated_at: @email_template.updated_at,
      sections: @email_template.sections.order(:position).includes(:template_variables).map { |s|
        {
          id: s.id,
          position: s.position,
          variables: s.template_variables.order(:position).map { |v|
            { id: v.id, name: v.name, variable_type: v.variable_type, default_value: v.default_value, position: v.position }
          }
        }
      }
    }
  end

  def create
    template = @current_account.email_templates.build(email_template_params)
    if template.save
      render json: { id: template.id, name: template.name }, status: :created
    else
      render json: { errors: template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @email_template.update(email_template_params)
      render json: { id: @email_template.id, name: @email_template.name }
    else
      render json: { errors: @email_template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @email_template.destroy
    head :no_content
  end

  private

  def set_email_template
    @email_template = @current_account.email_templates.find(params[:id])
  end

  def email_template_params
    params.require(:email_template).permit(:name, :raw_source_html)
  end
end
