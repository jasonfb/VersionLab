class AddOriginalRawSourceHtmlToEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :email_templates, :original_raw_source_html, :text

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE email_templates
          SET original_raw_source_html = raw_source_html
          WHERE original_raw_source_html IS NULL
        SQL
      end
    end
  end
end
