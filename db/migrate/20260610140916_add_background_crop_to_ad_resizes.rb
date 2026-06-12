class AddBackgroundCropToAdResizes < ActiveRecord::Migration[8.1]
  def change
    add_column :ad_resizes, :background_crop, :jsonb
  end
end
