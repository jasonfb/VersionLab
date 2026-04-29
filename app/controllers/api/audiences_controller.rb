class Api::AudiencesController < Api::BaseController
  before_action :set_client
  before_action :set_audience, only: [ :show, :update, :destroy, :summarize, :documents, :upload_document, :destroy_document ]

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

  def seed
    created = AudienceSamples::SAMPLES.map do |sample|
      @client.audiences.create!(sample)
    end
    render json: created.map { |a| audience_json(a) }, status: :created
  end

  def destroy
    @audience.destroy
    head :no_content
  end

  def summarize
    @audience.update!(ai_summary_state: :generating)
    AudienceSummaryJob.perform_later(@audience.id)
    render json: audience_json(@audience)
  end

  def documents
    docs = @audience.assets.order(created_at: :asc)
    render json: docs.map { |d| document_json(d) }
  end

  def upload_document
    file = params[:file]
    asset = @client.assets.build(
      name: file.original_filename,
      display_name: file.original_filename,
      assetable: @audience
    )
    asset.file.attach(file)

    if asset.save
      render json: document_json(asset), status: :created
    else
      render json: { errors: asset.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy_document
    doc = @audience.assets.find(params[:document_id])
    doc.destroy!
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
      :success_indicators_and_macro_trends,
      # Profile fields
      :client_url,
      :industry,
      :industry_other,
      :interaction_recency,
      :interaction_recency_other,
      :purchase_cadence,
      :purchase_cadence_other,
      :relationship_status,
      :primary_action,
      :primary_action_other,
      :order_value_band,
      :order_value_band_other,
      :promotion_sensitivity,
      :promotion_sensitivity_other,
      :communication_frequency,
      :communication_frequency_other,
      :product_visuals_impact,
      :general_insights,
      :product_categories_themes,
      # "Other" text for multiselects
      :outcomes_that_matter_other,
      :top_purchase_drivers_other,
      :action_prevention_factors_other,
      :checkout_friction_points_other,
      :communication_channels_other,
      :lifecycle_messages_other,
      # Array fields
      supporting_sites: [],
      outcomes_that_matter: [],
      top_purchase_drivers: [],
      action_prevention_factors: [],
      checkout_friction_points: [],
      communication_channels: [],
      lifecycle_messages: []
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
      # Profile fields
      client_url: a.client_url,
      industry: a.industry,
      industry_other: a.industry_other,
      interaction_recency: a.interaction_recency,
      interaction_recency_other: a.interaction_recency_other,
      purchase_cadence: a.purchase_cadence,
      purchase_cadence_other: a.purchase_cadence_other,
      relationship_status: a.relationship_status,
      primary_action: a.primary_action,
      primary_action_other: a.primary_action_other,
      order_value_band: a.order_value_band,
      order_value_band_other: a.order_value_band_other,
      promotion_sensitivity: a.promotion_sensitivity,
      promotion_sensitivity_other: a.promotion_sensitivity_other,
      communication_frequency: a.communication_frequency,
      communication_frequency_other: a.communication_frequency_other,
      product_visuals_impact: a.product_visuals_impact,
      general_insights: a.general_insights,
      product_categories_themes: a.product_categories_themes,
      supporting_sites: a.supporting_sites,
      outcomes_that_matter: a.outcomes_that_matter,
      top_purchase_drivers: a.top_purchase_drivers,
      action_prevention_factors: a.action_prevention_factors,
      checkout_friction_points: a.checkout_friction_points,
      communication_channels: a.communication_channels,
      lifecycle_messages: a.lifecycle_messages,
      outcomes_that_matter_other: a.outcomes_that_matter_other,
      top_purchase_drivers_other: a.top_purchase_drivers_other,
      action_prevention_factors_other: a.action_prevention_factors_other,
      checkout_friction_points_other: a.checkout_friction_points_other,
      communication_channels_other: a.communication_channels_other,
      lifecycle_messages_other: a.lifecycle_messages_other,
      # AI summary state
      ai_summary_state: a.ai_summary_state,
      ai_summary_generated_at: a.ai_summary_generated_at,
      updated_at: a.updated_at
    }
  end

  def document_json(d)
    {
      id: d.id,
      display_name: d.display_name || d.name,
      content_type: d.file.attached? ? d.file.blob.content_type : nil,
      byte_size: d.file.attached? ? d.file.blob.byte_size : nil,
      has_text: d.content_text.present?,
      created_at: d.created_at
    }
  end
end
