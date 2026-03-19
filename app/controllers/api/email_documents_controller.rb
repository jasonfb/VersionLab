class Api::EmailDocumentsController < Api::BaseController
  before_action :set_email

  def index
    render json: @email.email_documents.order(created_at: :asc).map { |d| document_json(d) }
  end

  def create
    file = params[:file]
    return render json: { error: "No file provided" }, status: :unprocessable_entity unless file

    doc = @email.email_documents.build(display_name: file.original_filename)
    doc.file.attach(file)

    if doc.save
      render json: document_json(doc), status: :created
    else
      render json: { errors: doc.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    doc = @email.email_documents.find(params[:id])
    doc.destroy!
    head :no_content
  end

  private

  def set_email
    client = @current_account.clients.find(params[:client_id])
    @email = client.emails.find(params[:email_id])
  end

  def document_json(doc)
    {
      id: doc.id,
      display_name: doc.display_name,
      content_type: doc.file.attached? ? doc.file.blob.content_type : nil,
      byte_size: doc.file.attached? ? doc.file.blob.byte_size : nil,
      has_extracted_text: doc.content_text.present?,
      created_at: doc.created_at
    }
  end
end
