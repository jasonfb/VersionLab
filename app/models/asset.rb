class Asset < ApplicationRecord
  belongs_to :account

  has_one_attached :file

  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(
      file,
      only_path: false,
      **ActionMailer::Base.default_url_options
    )
  end
end
