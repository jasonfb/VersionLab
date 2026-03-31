class BackfillAdClassifications < ActiveRecord::Migration[8.1]
  def up
    Ad.where(classifications_confirmed: false).find_each do |ad|
      next unless ad.parsed_layers.present? && ad.parsed_layers.any?

      AdClassifyService.new(ad).call
      ad.update!(classifications_confirmed: true)
    end
  end

  def down
    Ad.update_all(classified_layers: [], classifications_confirmed: false)
  end
end
