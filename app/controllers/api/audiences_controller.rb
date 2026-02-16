class Api::AudiencesController < Api::BaseController
  before_action :set_project
  before_action :set_audience, only: [:update, :destroy]

  def index
    audiences = @project.audiences.order(updated_at: :desc)
    render json: audiences.map { |a|
      { id: a.id, name: a.name, details: a.details, updated_at: a.updated_at }
    }
  end

  def create
    audience = @project.audiences.build(audience_params)
    if audience.save
      render json: { id: audience.id, name: audience.name, details: audience.details, updated_at: audience.updated_at }, status: :created
    else
      render json: { errors: audience.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @audience.update(audience_params)
      render json: { id: @audience.id, name: @audience.name, details: @audience.details, updated_at: @audience.updated_at }
    else
      render json: { errors: @audience.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @audience.destroy
    head :no_content
  end

  private

  def set_project
    @project = @current_account.projects.find(params[:project_id])
  end

  def set_audience
    @audience = @project.audiences.find(params[:id])
  end

  def audience_params
    params.require(:audience).permit(:name, :details)
  end
end
