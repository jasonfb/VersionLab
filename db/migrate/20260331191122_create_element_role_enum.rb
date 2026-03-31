class CreateElementRoleEnum < ActiveRecord::Migration[8.1]
  def change
    create_enum :element_role, %w[headline subhead body cta logo background decoration]
  end
end
