class Api::CampaignsController < Api::BaseController
  before_action :set_client

  def index
    render json: @client.campaigns.order(:name).map { |c| campaign_summary_json(c) }
  end

  def show
    campaign = @client.campaigns.find(params[:id])
    render json: campaign_full_json(campaign)
  end

  def create
    campaign = @client.campaigns.build(campaign_params)
    if campaign.save
      render json: campaign_summary_json(campaign), status: :created
    else
      render json: { errors: campaign.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    campaign = @client.campaigns.find(params[:id])
    text_changed = (campaign_params.keys & %w[description goals]).any? { |k| campaign_params[k] != campaign[k] }

    if campaign.update(campaign_params)
      CampaignSummaryJob.perform_later(campaign.id) if text_changed
      render json: campaign_full_json(campaign)
    else
      render json: { errors: campaign.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @client.campaigns.find(params[:id]).destroy!
    head :no_content
  end

  def summarize
    campaign = @client.campaigns.find(params[:id])
    campaign.update!(ai_summary_state: :idle)
    CampaignSummaryJob.perform_later(campaign.id)
    render json: { ai_summary_state: "generating" }
  end

  private

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end

  def campaign_params
    params.require(:campaign).permit(:name, :description, :goals, :status, :start_date, :end_date)
  end

  def campaign_summary_json(campaign)
    {
      id: campaign.id,
      name: campaign.name,
      status: campaign.status,
      start_date: campaign.start_date,
      end_date: campaign.end_date,
      ai_summary_state: campaign.ai_summary_state
    }
  end

  def campaign_full_json(campaign)
    campaign_summary_json(campaign).merge(
      description: campaign.description,
      goals: campaign.goals,
      ai_summary: campaign.ai_summary,
      ai_summary_generated_at: campaign.ai_summary_generated_at
    )
  end
end
