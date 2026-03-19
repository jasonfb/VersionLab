class EmailSummaryService
  class Error < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an expert email copywriter. You will receive one or more reference documents attached to a specific email.

    Your task is to write a concise, dense summary that an AI email copywriter can use as context when generating
    audience-targeted copy variants for this email. The summary should capture:
    - Key facts, data points, and statistics from the documents
    - Specific terminology, phrases, or messaging from the materials
    - Tone requirements or constraints suggested by the content
    - Any important details directly relevant to the email's subject matter

    Write a focused summary (aim for 200-500 words). Prioritise actionable details over general overviews.
  PROMPT

  def initialize(email)
    @email = email
  end

  def call
    account = @email.client.account
    ai_key, ai_model = find_ai_credentials(account)
    raise Error, "No text-capable AI key configured on this account" unless ai_key && ai_model

    document_texts = collect_document_texts
    raise Error, "No documents with extractable text" if document_texts.empty?

    prompt = build_user_prompt(document_texts)

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

  def find_ai_credentials(account)
    account.ai_keys.includes(ai_service: :ai_models).each do |key|
      model = key.ai_service.ai_models.find { |m| m.for_text? }
      return [ key, model ] if model
    end
    [ nil, nil ]
  end

  def collect_document_texts
    @email.email_documents.map do |doc|
      text = doc.content_text || extract_and_cache_text(doc)
      { name: doc.display_name, text: text }
    end.reject { |d| d[:text].blank? }
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
      end
    rescue StandardError => e
      Rails.logger.warn("Text extraction failed for email document #{doc.id}: #{e.message}")
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

  def build_user_prompt(document_texts)
    sections = []
    sections << "## Email Template\n#{@email.email_template.name}"

    document_texts.each do |doc|
      sections << "## Document: #{doc[:name]}\n#{doc[:text].truncate(15_000)}"
    end

    sections.join("\n\n")
  end

  def log_ai_call(account, ai_key, ai_model, messages, raw_response, summary)
    usage = raw_response["usage"] || {}
    AiLog.create!(
      account: account,
      call_type: :email_summary,
      ai_service_id: ai_key.ai_service_id,
      ai_model: ai_model,
      loggable: @email,
      prompt: messages.to_json,
      response: summary,
      prompt_tokens: usage["prompt_tokens"],
      completion_tokens: usage["completion_tokens"],
      total_tokens: usage["total_tokens"]
    )
  rescue StandardError => e
    Rails.logger.error("AiLog failed to save for email summary #{@email.id}: #{e.message}")
  end
end
