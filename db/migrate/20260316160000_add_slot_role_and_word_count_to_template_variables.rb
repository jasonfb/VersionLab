class AddSlotRoleAndWordCountToTemplateVariables < ActiveRecord::Migration[8.1]
  def up
    create_enum :template_variable_slot_role, %w[teaser_text eyebrow headline subheadline body cta_text image]
    add_column :template_variables, :slot_role, :enum, enum_type: :template_variable_slot_role
    add_column :template_variables, :word_count, :integer
  end

  def down
    remove_column :template_variables, :slot_role
    remove_column :template_variables, :word_count
    drop_enum :template_variable_slot_role
  end
end
