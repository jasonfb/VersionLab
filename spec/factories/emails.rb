FactoryBot.define do
  factory :email do
    client
    email_template
    campaign { nil }
    ai_service { nil }
    ai_model { nil }
    state { "setup" }
    ai_summary_state { "idle" }
  end
end
