class SeedAiModelPricing < ActiveRecord::Migration[8.1]
  # Pricing stored as integer cents per 1,000,000 tokens.
  # E.g. $2.00/M tokens → 200 cents/M
  PRICING = {
    # OpenAI
    "gpt-4o"       => { input: 250,  output: 1000 },  # $2.50/$10.00 per 1M
    "gpt-4o-mini"  => { input: 15,   output: 60   },  # $0.15/$0.60 per 1M
    "gpt-4.1"      => { input: 200,  output: 800  },  # $2.00/$8.00 per 1M
    "gpt-4.1-mini" => { input: 40,   output: 160  },  # $0.40/$1.60 per 1M

    # Anthropic
    "claude-sonnet-4-5-20250929" => { input: 300,  output: 1500 },  # $3.00/$15.00 per 1M
    "claude-haiku-3-5-20241022"  => { input: 80,   output: 400  },  # $0.80/$4.00 per 1M
    "claude-haiku-4-5-20251001"  => { input: 80,   output: 400  },  # $0.80/$4.00 per 1M
    "claude-sonnet-4-6"          => { input: 300,  output: 1500 },  # $3.00/$15.00 per 1M
    "claude-opus-4-6"            => { input: 1500, output: 7500 },  # $15.00/$75.00 per 1M

    # Google
    "gemini-2.0-flash" => { input: 10,  output: 40   },  # $0.10/$0.40 per 1M
    "gemini-2.5-pro"   => { input: 125, output: 1000 },  # $1.25/$10.00 per 1M

    # Perplexity
    "sonar"               => { input: 100, output: 100 },  # $1.00/$1.00 per 1M
    "sonar-pro"           => { input: 300, output: 1500 },  # $3.00/$15.00 per 1M
    "sonar-reasoning"     => { input: 100, output: 500  },  # $1.00/$5.00 per 1M
    "sonar-reasoning-pro" => { input: 200, output: 800  },  # $2.00/$8.00 per 1M
  }.freeze

  def up
    PRICING.each do |api_identifier, prices|
      AiModel.where(api_identifier: api_identifier).update_all(
        input_cost_per_mtok_cents: prices[:input],
        output_cost_per_mtok_cents: prices[:output]
      )
    end
  end

  def down
    AiModel.update_all(input_cost_per_mtok_cents: nil, output_cost_per_mtok_cents: nil)
  end
end
