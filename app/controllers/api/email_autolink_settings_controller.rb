class Api::EmailAutolinkSettingsController < Api::BaseController
  before_action :set_client
  before_action :set_email

  # GET /api/clients/:client_id/emails/:email_id/autolink_settings
  # Returns all top-level sections (with subsections) from the email's template,
  # each annotated with the email's current autolink setting for that section.
  def index
    template = @email.email_template
    settings_by_section = @email.email_section_autolink_settings.index_by(&:email_template_section_id)

    sections = template.sections.where(parent_id: nil).order(:position)
                       .includes(:template_variables, subsections: :template_variables)

    render json: sections.map { |s| section_json(s, settings_by_section) }
  end

  # PATCH /api/clients/:client_id/emails/:email_id/autolink_settings/:section_id
  # Upserts the autolink setting for one section (identified by section_id = email_template_section_id).
  def update
    section = @email.email_template.sections.find(params[:section_id])
    setting = @email.email_section_autolink_settings.find_or_initialize_by(email_template_section: section)
    setting.assign_attributes(autolink_setting_params)
    setting.save!
    render json: setting_json(setting)
  end

  private

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end

  def set_email
    @email = Email.joins(:email_template)
                  .where(email_templates: { client_id: @client.id })
                  .find(params[:email_id])
  end

  def autolink_setting_params
    params.require(:autolink_setting).permit(
      :autolink_mode, :link_mode, :url, :group_purpose,
      :link_color, :underline_links, :italic_links, :bold_links
    )
  end

  def section_json(section, settings_by_section)
    eligible_roles = %w[subheadline body]
    has_eligible_vars = section.template_variables.any? { |v| eligible_roles.include?(v.slot_role) }
    sub_has_eligible = section.subsections.any? { |sub|
      sub.template_variables.any? { |v| eligible_roles.include?(v.slot_role) }
    }

    {
      id: section.id,
      name: section.name,
      position: section.position,
      has_eligible_variables: has_eligible_vars || sub_has_eligible,
      autolink_setting: setting_json(settings_by_section[section.id]),
      subsections: section.subsections.order(:position).map { |sub|
        sub_has_vars = sub.template_variables.any? { |v| eligible_roles.include?(v.slot_role) }
        {
          id: sub.id,
          name: sub.name,
          position: sub.position,
          parent_id: sub.parent_id,
          has_eligible_variables: sub_has_vars,
          autolink_setting: setting_json(settings_by_section[sub.id])
        }
      }
    }
  end

  def setting_json(setting)
    return nil if setting.nil?
    {
      id: setting.id,
      email_template_section_id: setting.email_template_section_id,
      autolink_mode: setting.autolink_mode,
      link_mode: setting.link_mode,
      url: setting.url,
      group_purpose: setting.group_purpose,
      link_color: setting.link_color,
      underline_links: setting.underline_links,
      italic_links: setting.italic_links,
      bold_links: setting.bold_links
    }
  end
end
