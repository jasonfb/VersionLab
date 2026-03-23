class AdAudience < ApplicationRecord
  belongs_to :ad
  belongs_to :audience
end
