class ClientAppController < ApplicationController
  layout "client_app"
  before_action :authenticate_user!

  def index
  end
end
