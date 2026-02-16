class EmailTemplate < ApplicationRecord
  belongs_to :project
  has_many :sections, class_name: "EmailTemplateSection", dependent: :destroy
  has_many :template_variables, through: :sections

  def render_html(overrides = {})
    return "" if raw_source_html.blank?

    # Replace text variable placeholders: {{vl:uuid}}
    html = raw_source_html.gsub(/\{\{vl:([^}]+)\}\}/) do
      var_id = $1
      if overrides.key?(var_id)
        overrides[var_id]
      else
        template_variables.find { |v| v.id == var_id }&.default_value || ""
      end
    end

    # Handle image variables (data-vl-var attributes on <img> tags)
    doc = Nokogiri::HTML.fragment(html)
    doc.css("[data-vl-var]").each do |node|
      var_id = node["data-vl-var"]
      if overrides.key?(var_id) && node.name == "img"
        node["src"] = overrides[var_id]
      end
      node.remove_attribute("data-vl-var")
    end
    doc.to_html
  end
end
