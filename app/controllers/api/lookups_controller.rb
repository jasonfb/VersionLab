class Api::LookupsController < Api::BaseController
  def index
    render json: {
      organization_types: OrganizationType.all.map { |r| { id: r.id, name: r.name } },
      industries: Industry.all.map { |r| { id: r.id, name: r.name } },
      primary_audiences: PrimaryAudience.all.map { |r| { id: r.id, name: r.name } },
      tone_rules: ToneRule.all.map { |r| { id: r.id, name: r.name } },
      geographies: Geography.all.map { |r| { id: r.id, name: r.name } },
    }
  end
end
