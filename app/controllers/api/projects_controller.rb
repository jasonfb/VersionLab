class Api::ProjectsController < Api::BaseController
  def index
    projects = @current_account.projects.order(:name)
    render json: projects.map { |p|
      { id: p.id, name: p.name, updated_at: p.updated_at }
    }
  end

  def create
    project = @current_account.projects.build(project_params)
    if project.save
      render json: { id: project.id, name: project.name }, status: :created
    else
      render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:project).permit(:name)
  end
end
