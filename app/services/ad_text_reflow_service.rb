# frozen_string_literal: true

class AdTextReflowService
  class Error < StandardError; end

  def initialize(ad)
    @ad = ad
  end

  # Reposition text layers to avoid exclusion zones.
  #
  # Params:
  #   target_width, target_height: dimensions to lay out for
  #   exclusion_zones: [{ x:, y:, width:, height:, label: }, ...]
  #   text_layers: array of layer hashes with x, y, width, height, content, role, font_size
  #
  # Returns an array of layers with updated x/y positions.
  def call(target_width:, target_height:, exclusion_zones:, text_layers:)
    return text_layers if text_layers.empty?
    return text_layers if exclusion_zones.empty?

    # Skip reflow if no text overlaps any exclusion zone
    return text_layers unless any_overlap?(text_layers, exclusion_zones, target_width, target_height)

    ai_model = resolve_ai_model
    raise Error, "No AI service configured" unless ai_model

    messages = build_messages(target_width, target_height, exclusion_zones, text_layers)
    result = call_provider(ai_service_id: ai_model.ai_service_id, model: ai_model.api_identifier, messages: messages)
    log_ai_call(ai_model, messages, result)

    apply_positions(text_layers, result[:content], target_width, target_height)
  end

  private

  def any_overlap?(layers, zones, tw, th)
    layers.any? do |l|
      lx = l["x"].to_f
      ly = l["y"].to_f
      lw = l["width"].to_f
      lh = l["height"].to_f
      # Use font_size as approximate text height if height covers full canvas
      if lh >= th * 0.8
        lh = l["font_size"].to_f * 1.5
      end

      zones.any? do |z|
        zx = z[:x] || z["x"]
        zy = z[:y] || z["y"]
        zw = z[:width] || z["width"]
        zh = z[:height] || z["height"]
        # Rectangle overlap test
        lx < zx.to_f + zw.to_f &&
          lx + lw > zx.to_f &&
          ly < zy.to_f + zh.to_f &&
          ly + lh > zy.to_f
      end
    end
  end

  def resolve_ai_model
    if @ad.ai_model && AiKey.exists?(ai_service_id: @ad.ai_model.ai_service_id)
      return @ad.ai_model
    end
    service_ids_with_keys = AiKey.pluck(:ai_service_id)
    return nil if service_ids_with_keys.empty?
    AiModel.where(ai_service_id: service_ids_with_keys).order(:created_at).first
  end

  def build_messages(tw, th, zones, layers)
    zone_desc = zones.map { |z|
      x = z[:x] || z["x"]
      y = z[:y] || z["y"]
      w = z[:width] || z["width"]
      h = z[:height] || z["height"]
      label = z[:label] || z["label"]
      "  - #{label}: x=#{x}, y=#{y}, width=#{w}, height=#{h}"
    }.join("\n")

    layer_desc = layers.map { |l|
      "  - id: #{l['id']}, role: #{l['role']}, content: \"#{l['content']}\", font_size: #{l['font_size']}, current_x: #{l['x']}, current_y: #{l['y']}, width: #{l['width']}, height: #{l['height']}"
    }.join("\n")

    [
      { role: "system", content: build_system_prompt },
      { role: "user", content: <<~PROMPT }
        Canvas: #{tw}×#{th} pixels

        EXCLUSION ZONES (do not place text here):
        #{zone_desc}

        TEXT LAYERS to position:
        #{layer_desc}

        Return the repositioned layers as JSON.
      PROMPT
    ]
  end

  def build_system_prompt
    <<~PROMPT
      You are an expert advertising layout designer. You will be given:
      1. A canvas size
      2. Exclusion zones (faces, logos, subjects) where text must NOT be placed
      3. Text layers with their current positions, roles, and font sizes

      Your job: reposition the text layers so they avoid ALL exclusion zones while maintaining a clean, professional ad layout.

      Layout principles:
      - Headlines go near the top or in the most prominent safe area
      - Subheads go near/below the headline
      - CTAs go at the bottom or in a visually distinct safe area
      - Body text fills remaining safe space
      - Decoration/taglines can go anywhere there's room
      - Keep text layers from overlapping each other
      - Prefer left-aligned or centered text placement
      - Leave at least 10px padding from canvas edges
      - Keep the width reasonable for readability (don't stretch text across the entire canvas if not needed)
      - A text layer's bounding box (x, y, width, font_size * 1.4 for single line) must not overlap any exclusion zone

      Respond with valid JSON only:
      {
        "layers": [
          { "id": "<layer_id>", "x": <new_x>, "y": <new_y>, "width": <new_width> },
          ...
        ]
      }

      Include every input layer. Only change x, y, and width — do not change content, role, or font_size.
    PROMPT
  end

  def call_provider(ai_service_id:, model:, messages:)
    AiProviders::Factory.for_text(AiService.find(ai_service_id)).complete(
      model: model,
      messages: messages,
      temperature: 0.3,
      json_mode: true
    )
  rescue AiProviders::Base::Error => e
    raise Error, e.message
  end

  def log_ai_call(ai_model, messages, result)
    AiLog.create!(
      account: @ad.client.account,
      call_type: :ad,
      ai_service_id: ai_model.ai_service_id,
      ai_model: ai_model,
      loggable: @ad,
      prompt: messages.to_json,
      response: result[:content],
      prompt_tokens: result[:prompt_tokens],
      completion_tokens: result[:completion_tokens],
      total_tokens: result[:total_tokens]
    )
  rescue StandardError => e
    Rails.logger.error("AiLog failed to save: #{e.message}")
  end

  def apply_positions(original_layers, json_string, max_w, max_h)
    raise Error, "Empty response from AI" if json_string.blank?
    cleaned = json_string.sub(/\A\s*```(?:json)?\s*\n?/, "").sub(/\n?\s*```\s*\z/, "")
    parsed = JSON.parse(cleaned)
    ai_layers = parsed.is_a?(Hash) ? parsed["layers"] : nil
    raise Error, "Expected a JSON object with a 'layers' array" unless ai_layers.is_a?(Array)

    by_id = ai_layers.index_by { |l| l["id"] }

    original_layers.map do |layer|
      suggestion = by_id[layer["id"]]
      next layer unless suggestion

      updated = layer.dup
      new_x = suggestion["x"].to_i.clamp(0, max_w - 30)
      new_y = suggestion["y"].to_i.clamp(0, max_h - 20)
      new_w = suggestion["width"]&.to_i

      updated["x"] = new_x.to_s
      updated["y"] = new_y.to_s
      updated["width"] = new_w.clamp(60, max_w - new_x).to_s if new_w

      updated
    end
  rescue JSON::ParserError => e
    raise Error, "Failed to parse AI response: #{e.message}"
  end
end
