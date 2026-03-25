FactoryBot.define do
  factory :ai_log do
    account
    ai_service { nil }
    ai_model { nil }
    loggable { nil }
    call_type { "email" }
  end
end
