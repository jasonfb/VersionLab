class Api::BrandProfilesController < Api::BaseController
  before_action :set_client

  def show
    bp = @client.brand_profile
    return render json: nil, status: :not_found unless bp
    render json: brand_profile_json(bp)
  end

  def upsert
    bp = @client.brand_profile || @client.build_brand_profile

    BrandProfile.transaction do
      bp.assign_attributes(scalar_params)
      bp.save!

      sync_associations(bp, :primary_audiences, PrimaryAudience, :brand_profile_primary_audiences,
                        params[:primary_audience_ids])
      sync_associations(bp, :tone_rules, ToneRule, :brand_profile_tone_rules,
                        params[:tone_rule_ids])
      sync_associations(bp, :geographies, Geography, :brand_profile_geographies,
                        params[:geography_ids])
    end

    render json: brand_profile_json(bp.reload)
  end

  private

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end

  def scalar_params
    p = params.permit(
      :organization_name, :primary_domain, :organization_type_id, :industry_id,
      :mission_statement, :link_color, :underline_links, :italic_links, :bold_links,
      core_programs: [], approved_vocabulary: [], blocked_vocabulary: [], color_palette: []
    )
    # Treat empty string IDs as nil
    p[:organization_type_id] = nil if p[:organization_type_id].blank?
    p[:industry_id] = nil if p[:industry_id].blank?
    p
  end

  def sync_associations(bp, association, klass, join_table_assoc, ids)
    return unless ids
    ids = Array(ids).reject(&:blank?)
    records = klass.where(id: ids)
    bp.send("#{association}=", records)
  end

  def brand_profile_json(bp)
    {
      id: bp.id,
      organization_name: bp.organization_name,
      primary_domain: bp.primary_domain,
      organization_type_id: bp.organization_type_id,
      industry_id: bp.industry_id,
      mission_statement: bp.mission_statement,
      core_programs: bp.core_programs || [],
      approved_vocabulary: bp.approved_vocabulary || [],
      blocked_vocabulary: bp.blocked_vocabulary || [],
      color_palette: bp.color_palette || [],
      link_color: bp.link_color,
      underline_links: bp.underline_links,
      italic_links: bp.italic_links,
      bold_links: bp.bold_links,
      primary_audience_ids: bp.primary_audiences.map(&:id),
      tone_rule_ids: bp.tone_rules.map(&:id),
      geography_ids: bp.geographies.map(&:id),
    }
  end
end
