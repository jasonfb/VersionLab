class CampaignSummaryService
  class Error < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a campaign strategist. You will receive information about a marketing campaign including
    a description, goals, reference documents, and reference links.

    Your task is to write a comprehensive campaign summary that an email copywriter can use as context.
    The summary should capture:
    - Campaign purpose, goals, and key messages
    - Target audience and tone requirements
    - Specific terminology, phrases, or messaging requirements
    - Brand voice requirements or constraints
    - Any important details from the provided documents and links

    Write a dense, detailed summary (aim for 400-800 words). Use clear section headings.
    Focus on actionable details relevant to writing email copy.
  PROMPT

  def initialize(campaign)
    @campaign = campaign
  end

  def call
    account = @campaign.client.account
    ai_key, ai_model = find_ai_credentials(account)
    raise Error, "No text-capable AI key configured on this account" unless ai_key && ai_model

    document_texts = collect_document_texts
    link_summaries = collect_link_summaries

    prompt = build_user_prompt(document_texts, link_summaries)

    messages = [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: prompt }
    ]

    client = OpenAI::Client.new(access_token: ai_key.api_key)
    response = client.chat(
      parameters: {
        model: ai_model.api_identifier,
        messages: messages,
        temperature: 0.3
      }
    )

    summary = response.dig("choices", 0, "message", "content")
    raise Error, "Empty response from AI" if summary.blank?

    log_ai_call(account, ai_key, ai_model, messages, response, summary)

    summary
  end

  private

  def log_ai_call(account, ai_key, ai_model, messages, raw_response, summary)
    usage = raw_response["usage"] || {}
    AiLog.create!(
      account: account,
      call_type: :campaign_summary,
      ai_service_id: ai_key.ai_service_id,
      ai_model: ai_model,
      loggable: @campaign,
      prompt: messages.to_json,
      response: summary,
      prompt_tokens: usage["prompt_tokens"],
      completion_tokens: usage["completion_tokens"],
      total_tokens: usage["total_tokens"]
    )
  rescue StandardError => e
    Rails.logger.error("AiLog failed to save for campaign #{@campaign.id}: #{e.message}")
  end

  def find_ai_credentials(account)
    account.ai_keys.includes(ai_service: :ai_models).each do |key|
      model = key.ai_service.ai_models.find { |m| m.for_text? }
      return [ key, model ] if model
    end
    [ nil, nil ]
  end

  def collect_document_texts
    @campaign.campaign_documents.map do |doc|
      text = doc.content_text || extract_and_cache_text(doc)
      { name: doc.display_name, text: text }
    end
  end

  def extract_and_cache_text(doc)
    return nil unless doc.file.attached?

    text = begin
      content_type = doc.file.blob.content_type
      filename = doc.file.blob.filename.to_s

      if content_type == "application/pdf"
        extract_pdf(doc)
      elsif content_type.include?("wordprocessingml") || filename.end_with?(".docx")
        extract_docx(doc)
      else
        nil
      end
    rescue StandardError => e
      Rails.logger.warn("Text extraction failed for document #{doc.id}: #{e.message}")
      nil
    end

    doc.update_column(:content_text, text) if text.present?
    text
  end

  def extract_pdf(doc)
    doc.file.open do |file|
      reader = PDF::Reader.new(file.path)
      reader.pages.map(&:text).join("\n").strip.truncate(60_000)
    end
  end

  def extract_docx(doc)
    doc.file.open do |file|
      Zip::File.open(file.path) do |zip|
        entry = zip.glob("word/document.xml").first
        return nil unless entry
        xml = entry.get_input_stream.read
        parsed = Nokogiri::XML(xml)
        parsed.remove_namespaces!
        parsed.css("t").map(&:text).join(" ").strip.truncate(60_000)
      end
    end
  end

  def collect_link_summaries
    @campaign.campaign_links.map do |link|
      { url: link.url, title: link.title, description: link.link_description }
    end
  end

  def build_user_prompt(document_texts, link_summaries)
    sections = []

    sections << "## Campaign Name\n#{@campaign.name}"

    if @campaign.description.present?
      sections << "## Description\n#{@campaign.description}"
    end

    if @campaign.goals.present?
      sections << "## Goals & Objectives\n#{@campaign.goals}"
    end

    if @campaign.start_date.present? || @campaign.end_date.present?
      dates = [ @campaign.start_date&.to_s, @campaign.end_date&.to_s ].compact.join(" to ")
      sections << "## Campaign Dates\n#{dates}"
    end

    document_texts.each do |doc|
      if doc[:text].present?
        sections << "## Document: #{doc[:name]}\n#{doc[:text].truncate(15_000)}"
      else
        sections << "## Document: #{doc[:name]}\n(Binary file — text could not be extracted)"
      end
    end

    link_summaries.each do |link|
      parts = [ "URL: #{link[:url]}" ]
      parts << "Title: #{link[:title]}" if link[:title].present?
      parts << "Description: #{link[:description]}" if link[:description].present?
      sections << "## Reference Link\n#{parts.join("\n")}"
    end

    sections.join("\n\n")
  end
end
