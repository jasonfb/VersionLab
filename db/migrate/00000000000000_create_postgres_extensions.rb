# frozen_string_literal: true

class CreatePostgresExtensions < ActiveRecord::Migration[7.0]
  def change
    ActiveRecord::Base.connection.execute('CREATE EXTENSION pgcrypto;')
  end
end

