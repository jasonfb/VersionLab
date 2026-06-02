class AddAiModelPreferencesToAccounts < ActiveRecord::Migration[8.1]
  def change
    # Per-category AI model preferences. Shape:
    # {
    #   "email_copy":        { "ai_model_id": "<uuid>" },
    #   "ad_classification": { "ai_model_id": "<uuid>" },
    #   "ad_vision":         { "ai_model_id": "<uuid>" },
    #   "ad_copy":           { "ai_model_id": "<uuid>" },
    #   "ad_layout":         { "ai_model_id": "<uuid>" }
    # }
    add_column :accounts, :ai_model_preferences, :jsonb, default: {}
  end
end
