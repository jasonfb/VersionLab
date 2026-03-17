class Api::ClientsController < Api::BaseController
  def index
    clients = accessible_clients.order(:name)
    render json: clients.map { |c|
      { id: c.id, name: c.name, updated_at: c.updated_at }
    }
  end

  def create
    client = @current_account.clients.build(client_params)
    if client.save
      render json: { id: client.id, name: client.name }, status: :created
    else
      render json: { errors: client.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    client = @current_account.clients.visible.find(params[:id])
    if client.update(client_params)
      render json: { id: client.id, name: client.name, updated_at: client.updated_at }
    else
      render json: { errors: client.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def client_params
    params.require(:client).permit(:name)
  end
end
