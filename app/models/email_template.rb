class EmailTemplate < ApplicationRecord
  belongs_to :project
  has_many :sections, class_name: "EmailTemplateSection", dependent: :destroy
  has_many :template_variables, through: :sections

  def render_html(overrides = {})
    return "" if raw_source_html.blank?

    doc = Nokogiri::HTML.fragment(raw_source_html)
    doc.css("[data-vl-var]").each do |node|
      var_id = node["data-vl-var"]
      if overrides.key?(var_id)
        if node.name == "img"
          node["src"] = overrides[var_id]
        else
          node.inner_html = overrides[var_id]
        end
      end
      node.remove_attribute("data-vl-var")
    end
    doc.to_html
  end
end
