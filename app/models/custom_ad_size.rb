class CustomAdSize < ApplicationRecord
  belongs_to :client
  belongs_to :ad_shape, optional: true

  validates :label, presence: true
  validates :width, presence: true, numericality: { greater_than: 0 }
  validates :height, presence: true, numericality: { greater_than: 0 }
  validates :width, uniqueness: { scope: [:client_id, :height], message: "and height combination already exists for this client" }

  # Override chain: explicit ad_shape > computed from dimensions
  def effective_shape
    ad_shape&.name&.to_sym || AdLayout::AspectRatioBucket.classify(width, height)
  end
end
