class Api::AiLogsController < Api::BaseController
  def index
    logs = @current_account.ai_logs
                           .includes(ai_model: :ai_service)
                           .order(created_at: :desc)

    page     = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 50).to_i
    total    = logs.count

    records = logs.offset((page - 1) * per_page).limit(per_page)

    render json: {
      logs: records.map { |l|
        cost = l._cost_to_us_cents || 0
        {
          id:                l.id,
          created_at:        l.created_at.iso8601,
          call_type:         l.call_type,
          ai_service_name:   l.ai_model&.ai_service&.name,
          ai_model_name:     l.ai_model&.name,
          input_tokens:      l.prompt_tokens.to_i,
          output_tokens:     l.completion_tokens.to_i,
          total_tokens:      l.total_tokens.to_i,
          input_cost_cents:  (l._input_cost_cents || 0).to_f.round(6),
          output_cost_cents: (l._output_cost_cents || 0).to_f.round(6),
          cost_to_us_cents:  cost.to_f.round(6),
          vl_tokens:         (cost * 10).to_f.round(2)
        }
      },
      page:        page,
      per_page:    per_page,
      total_count: total,
      total_pages: (total.to_f / per_page).ceil
    }
  end
end
