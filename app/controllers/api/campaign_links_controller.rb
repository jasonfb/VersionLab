class Api::CampaignLinksController < Api::BaseController
  before_action :set_campaign

  def index
    render json: @campaign.campaign_links.order(created_at: :asc).map { |l| link_json(l) }
  end

  def create
    link = @campaign.campaign_links.build(url: params[:url])

    if link.save
      render json: link_json(link), status: :created
    else
      render json: { errors: link.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    link = @campaign.campaign_links.find(params[:id])
    link.destroy!
    head :no_content
  end

  private

  def set_campaign
    client = @current_account.clients.find(params[:client_id])
    @campaign = client.campaigns.find(params[:campaign_id])
  end

  def link_json(link)
    {
      id: link.id,
      url: link.url,
      title: link.title,
      description: link.link_description,
      image_url: link.image_url,
      fetched_at: link.fetched_at,
      created_at: link.created_at
    }
  end
end
