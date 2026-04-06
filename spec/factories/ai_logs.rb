# == Schema Information
#
# Table name: ai_logs
# Database name: primary
#
#  id                :uuid             not null, primary key
#  _cost_to_us_cents :integer
#  call_type         :enum             not null
#  completion_tokens :integer
#  loggable_type     :string
#  prompt            :text
#  prompt_tokens     :integer
#  response          :text
#  total_tokens      :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  ai_model_id       :uuid
#  ai_service_id     :uuid
#  loggable_id       :uuid
#
# Indexes
#
#  idx_ai_logs_on_loggable      (loggable_type,loggable_id)
#  index_ai_logs_on_account_id  (account_id)
#  index_ai_logs_on_created_at  (created_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :ai_log do
    account
    ai_service { nil }
    ai_model { nil }
    loggable { nil }
    call_type { "email" }
  end
end
