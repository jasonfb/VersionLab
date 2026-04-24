class SetAccountsToPerplexity < ActiveRecord::Migration[8.1]
  def up
    service = AiService.find_by!(slug: "perplexity")
    model = service.ai_models.find_by!(api_identifier: "sonar")

    Account.update_all(
      customer_chooses_ai: false,
      ai_service_id: service.id,
      ai_model_id: model.id
    )
  end

  def down
    Account.update_all(
      customer_chooses_ai: true,
      ai_service_id: nil,
      ai_model_id: nil
    )
  end
end
