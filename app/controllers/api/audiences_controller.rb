class Api::AudiencesController < Api::BaseController
  before_action :set_client
  before_action :set_audience, only: [:show, :update, :destroy]

  def index
    audiences = @client.audiences.order(updated_at: :desc)
    render json: audiences.map { |a| audience_json(a) }
  end

  def show
    render json: audience_json(@audience)
  end

  def create
    audience = @client.audiences.build(audience_params)
    if audience.save
      render json: audience_json(audience), status: :created
    else
      render json: { errors: audience.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @audience.update(audience_params)
      render json: audience_json(@audience)
    else
      render json: { errors: @audience.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @audience.destroy
    head :no_content
  end

  private

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end

  def set_audience
    @audience = @client.audiences.find(params[:id])
  end

  def audience_params
    params.require(:audience).permit(
      :name, :details,
      :executive_summary,
      :demographics_and_financial_capacity,
      :lapse_diagnosis,
      :relationship_state_and_pre_lapse_indicators,
      :motivational_drivers_and_messaging_framework,
      :strategic_reactivation_and_upgrade_cadence,
      :creative_and_imagery_rules,
      :risk_scoring_model,
      :prohibited_patterns,
      :success_indicators_and_macro_trends
    )
  end

  def audience_json(a)
    {
      id: a.id,
      name: a.name,
      details: a.details,
      executive_summary: a.executive_summary,
      demographics_and_financial_capacity: a.demographics_and_financial_capacity,
      lapse_diagnosis: a.lapse_diagnosis,
      relationship_state_and_pre_lapse_indicators: a.relationship_state_and_pre_lapse_indicators,
      motivational_drivers_and_messaging_framework: a.motivational_drivers_and_messaging_framework,
      strategic_reactivation_and_upgrade_cadence: a.strategic_reactivation_and_upgrade_cadence,
      creative_and_imagery_rules: a.creative_and_imagery_rules,
      risk_scoring_model: a.risk_scoring_model,
      prohibited_patterns: a.prohibited_patterns,
      success_indicators_and_macro_trends: a.success_indicators_and_macro_trends,
      updated_at: a.updated_at
    }
  end
end
