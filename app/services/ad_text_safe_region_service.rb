# frozen_string_literal: true

class AdTextSafeRegionService
  class Error < StandardError; end

  def initialize(ad)
    @ad = ad
  end

  # Analyze a background image at the given target dimensions and return
  # exclusion zones (faces, key subjects) where text must NOT be placed.
  # Everything outside these zones is considered safe for text.
  #
  # Returns:
  #   { exclusion_zones: [{ x:, y:, width:, height:, label: }, ...],
  #     target_width:, target_height: }
  #
  # Coordinates are pixels relative to the center-cropped target dimensions.
  def call(target_width:, target_height:)
    bg_layer = (@ad.classified_layers || []).find { |l| l["type"] == "background" }
    raise Error, "No background image found" unless bg_layer&.dig("href").present?

    ai_model = resolve_ai_model
    raise Error, "No AI service configured" unless ai_model

    # Center-crop the background to target dimensions
    cropped_b64 = center_crop_background(bg_layer["href"], target_width, target_height)
    raise Error, "Failed to crop background image" unless cropped_b64

    messages = build_messages(cropped_b64, target_width, target_height)
    result = call_provider(ai_service_id: ai_model.ai_service_id, model: ai_model.api_identifier, messages: messages)
    log_ai_call(ai_model, messages, result)

    zones = parse_exclusion_zones(result[:content], target_width, target_height)
    { exclusion_zones: zones, target_width: target_width, target_height: target_height }
  end

  private

  def resolve_ai_model
    @ad.client.account.ai_model_for(:ad_vision, ad: @ad)
  end

  # Center-crop the background image (base64 data URI) to target dimensions.
  # If the source is smaller than the target in either dimension, returns nil
  # (the background doesn't fit — no regions to detect).
  def center_crop_background(href, target_w, target_h)
    # Decode the base64 data URI
    raw = if href.start_with?("data:")
      mime_and_data = href.sub(%r{\Adata:[^;]+;base64,}, "")
      Base64.decode64(mime_and_data)
    else
      return nil # external URLs not supported yet
    end

    image = Vips::Image.new_from_buffer(raw, "")
    src_w = image.width
    src_h = image.height

    # If target is larger than source, can't center-crop
    return nil if target_w > src_w || target_h > src_h

    # Calculate center-crop region
    scale_x = target_w.to_f / src_w
    scale_y = target_h.to_f / src_h
    scale = [ scale_x, scale_y ].max

    scaled_w = (src_w * scale).round
    scaled_h = (src_h * scale).round

    # Resize then crop
    resized = image.resize(scale)
    crop_x = [ (resized.width - target_w) / 2, 0 ].max
    crop_y = [ (resized.height - target_h) / 2, 0 ].max
    cropped = resized.crop(crop_x, crop_y,
      [ target_w, resized.width ].min,
      [ target_h, resized.height ].min)

    # Upscale to at least 900px wide for better AI vision accuracy
    min_dimension = 900
    upscale = if cropped.width < min_dimension
      min_dimension.to_f / cropped.width
    else
      1.0
    end
    final = upscale > 1.0 ? cropped.resize(upscale) : cropped

    png_data = final.pngsave_buffer(compression: 6)
    Base64.strict_encode64(png_data)
  rescue => e
    Rails.logger.warn("AdTextSafeRegionService: crop failed: #{e.message}")
    nil
  end

  def build_messages(image_b64, target_w, target_h)
    [
      { role: "system", content: build_system_prompt(target_w, target_h) },
      {
        role: "user",
        content: [
          { type: "image_base64", media_type: "image/png", data: image_b64 },
          { type: "text", text: "Analyze this #{target_w}×#{target_h} ad background image. Identify the EXCLUSION ZONES where text must NOT be placed, as described in the system prompt." }
        ]
      }
    ]
  end

  def build_system_prompt(target_w, target_h)
    <<~PROMPT
      You are an expert at precisely locating faces and subjects in images.

      You will receive an image that has been scaled up for clarity. The ACTUAL canvas size is #{target_w}×#{target_h} pixels. All coordinates in your response must be in the original #{target_w}×#{target_h} coordinate space.

      Your job: identify EXCLUSION ZONES — tight rectangular bounding boxes around faces and key subjects where advertising text must NOT be placed.

      WHAT TO MARK:
      - Every human face: draw a box from the top of the forehead to the bottom of the chin, left edge of face to right edge. Include the full face but NOT extra background.
      - Logos or brand marks with existing text
      - Key product imagery that is the focal subject

      WHAT NOT TO MARK:
      - Bodies, arms, hands, clothing (only faces matter for text avoidance)
      - Blurry/out-of-focus areas, sky, walls, gradients, bokeh
      - Solid color bars or banners (these are GOOD for text)

      PRECISION IS CRITICAL. For each face:
      1. Identify the exact center of the face in the image
      2. Estimate the face width and height carefully
      3. Place the bounding box so the face is centered within it
      4. The box should be tight — just enough to cover forehead to chin, ear to ear

      Common mistakes to avoid:
      - Don't shift boxes left/right of the actual face position
      - Don't confuse one person's face with another's
      - If a face is at the right edge of the image, the box should be at the right edge too
      - Remember: (0,0) is the TOP-LEFT corner. X increases rightward, Y increases downward.

      Rules:
      - Return 1–10 exclusion zones
      - Coordinates are in pixels from top-left (0,0) in the #{target_w}×#{target_h} space
      - x + width must not exceed #{target_w}, y + height must not exceed #{target_h}
      - Include a short label (e.g., "left child's face", "center woman's face")

      Respond with valid JSON only:
      {
        "exclusion_zones": [
          { "x": 0, "y": 0, "width": 100, "height": 100, "label": "description" },
          ...
        ]
      }
    PROMPT
  end

  def call_provider(ai_service_id:, model:, messages:)
    AiProviders::Factory.for_text(AiService.find(ai_service_id)).complete(
      model: model,
      messages: messages,
      temperature: 0.2,
      json_mode: true
    )
  rescue AiProviders::Base::Error => e
    raise Error, e.message
  end

  def log_ai_call(ai_model, messages, result)
    # Strip image data from logged prompt to avoid storing huge base64 blobs
    safe_messages = messages.map do |m|
      if m[:content].is_a?(Array)
        { role: m[:role], content: m[:content].map { |p| p[:type] == "image_base64" ? { type: "image_base64", data: "[#{p[:data].length} chars]" } : p } }
      else
        m
      end
    end

    AiLog.create!(
      account: @ad.client.account,
      call_type: :ad,
      ai_service_id: ai_model.ai_service_id,
      ai_model: ai_model,
      loggable: @ad,
      prompt: safe_messages.to_json,
      response: result[:content],
      prompt_tokens: result[:prompt_tokens],
      completion_tokens: result[:completion_tokens],
      total_tokens: result[:total_tokens]
    )
  rescue StandardError => e
    Rails.logger.error("AiLog failed to save: #{e.message}")
  end

  def parse_exclusion_zones(json_string, max_w, max_h)
    raise Error, "Empty response from AI" if json_string.blank?
    cleaned = json_string.sub(/\A\s*```(?:json)?\s*\n?/, "").sub(/\n?\s*```\s*\z/, "")
    parsed = JSON.parse(cleaned)
    zones = parsed.is_a?(Hash) ? parsed["exclusion_zones"] : nil
    raise Error, "Expected a JSON object with an 'exclusion_zones' array" unless zones.is_a?(Array)

    # Validate and clamp zones
    zones.filter_map do |r|
      x = r["x"].to_i
      y = r["y"].to_i
      w = r["width"].to_i
      h = r["height"].to_i
      label = r["label"].to_s

      # Clamp to bounds
      x = x.clamp(0, max_w - 1)
      y = y.clamp(0, max_h - 1)
      w = [ w, max_w - x ].min
      h = [ h, max_h - y ].min

      next if w < 30 || h < 20 # too small to be useful

      { x: x, y: y, width: w, height: h, label: label }
    end
  rescue JSON::ParserError => e
    raise Error, "Failed to parse AI response: #{e.message}"
  end
end
