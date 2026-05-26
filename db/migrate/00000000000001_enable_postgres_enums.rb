# frozen_string_literal: true

class EnablePostgresEnums < ActiveRecord::Migration[7.1]
  def up
    enable_extension "plpgsql"
  end
end


