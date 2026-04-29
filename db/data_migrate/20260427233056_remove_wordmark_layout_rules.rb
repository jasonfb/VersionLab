class RemoveWordmarkLayoutRules < ActiveRecord::Migration[8.1]
  def up
    AdShapeLayoutRule.where(role: "wordmark").destroy_all
  end

  def down
    # Wordmark rules were removed intentionally; no restore needed
  end
end
