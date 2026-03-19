class EmailAudience < ApplicationRecord
  belongs_to :email
  belongs_to :audience
end
