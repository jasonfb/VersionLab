FactoryBot.define do
  factory :ai_usage_summary do
    account
    ai_model
    usage_month { Date.current.beginning_of_month }
    _cost_to_us_cents { 100 }
    _input_tokens { 5000 }
    _output_tokens { 2000 }
    _total_tokens { 7000 }
  end
end
