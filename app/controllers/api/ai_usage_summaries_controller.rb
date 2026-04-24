class Api::AiUsageSummariesController < Api::BaseController
  def index
    summaries = @current_account.ai_usage_summaries
                  .includes(ai_model: :ai_service)
                  .order(usage_month: :desc, created_at: :desc)

    # Paginate by month
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 12).to_i

    months = summaries.reorder(usage_month: :desc).distinct.pluck(:usage_month).sort.reverse
    paginated_months = months.slice((page - 1) * per_page, per_page) || []

    records = summaries.where(usage_month: paginated_months)

    grouped = paginated_months.map { |month|
      month_records = records.select { |r| r.usage_month == month }
      {
        month: month.strftime("%Y-%m"),
        models: month_records.map { |r|
          cost = r._cost_to_us_cents || 0
          {
            id: r.id,
            ai_service_name: r.ai_model.ai_service.name,
            ai_model_name: r.ai_model.name,
            input_tokens: r._input_tokens,
            output_tokens: r._output_tokens,
            total_tokens: r._total_tokens,
            cost_to_us_cents: cost.to_f.round(6),
            vl_tokens: (cost * 10).to_f.round(1)
          }
        }
      }
    }

    render json: {
      usage: grouped,
      page: page,
      total_pages: (months.size.to_f / per_page).ceil
    }
  end
end
