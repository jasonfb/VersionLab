class Audience < ApplicationRecord
  belongs_to :client

  validates :name, presence: true
end
