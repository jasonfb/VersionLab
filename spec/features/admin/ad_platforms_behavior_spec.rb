require 'rails_helper'

describe 'interaction for Admin::AdPlatformsController', type: :feature, js: true do
  include HotGlue::ControllerHelper
  include ActionView::RecordIdentifier
  include Rails.application.routes.url_helpers

    # HOTGLUE-SAVESTART
  # HOTGLUE-END

  let(:admin_user) do
    user = create(:user)
    admin_role = Role.find_or_create_by!(name: "admin")
    user.roles << admin_role
    user
  end

  before { login_as(admin_user, scope: :user) }



  let!(:ad_platform1) {
    ad_platform = create(:ad_platform , 
                          name: FFaker::Movie.title, 
                          position: rand(100) )

    ad_platform.save!
    ad_platform
  }
  
  describe "index" do
    it "should show me the list" do
      visit admin_ad_platforms_path
      expect(page).to have_content(ad_platform1.name)
      expect(page).to have_content(ad_platform1.position)
    end
  end

  describe "new & create" do
    it "should create a new Ad Platform" do
      visit admin_ad_platforms_path
      click_link "New Ad Platform"
      expect(page).to have_selector(:xpath, './/h3[contains(., "New Ad Platform")]')
      new_name = FFaker::Movie.title 
      find("[name='ad_platform[name]']").fill_in(with: new_name)
      new_position = rand(10) 
      find("[name='ad_platform[position]']").fill_in(with: new_position)
      click_button "Save"
      expect(page).to have_content("Successfully created")

      expect(page).to have_content(new_name)
      expect(page).to have_content(new_position)
    end
  end


  describe "edit & update" do
    it "should return an editable form" do
      visit admin_ad_platforms_path
      find("a.edit-ad_platform-button[href='/admin/ad_platforms/#{ad_platform1.id}/edit']").click

      expect(page).to have_content("Editing #{ad_platform1.name.squish || "(no name)"}")
      new_name = FFaker::Movie.title 
      find("[name='ad_platform[name]']").fill_in(with: new_name)
      new_position = rand(10) 
      find("[name='ad_platform[position]']").fill_in(with: new_position)
      click_button "Save"
      within("turbo-frame#admin__#{dom_id(ad_platform1)} ") do
        expect(page).to have_content(new_name)
       expect(page).to have_content(new_position)
      end
    end
  end 

  describe "destroy" do
    it "should destroy" do
      visit admin_ad_platforms_path
      accept_alert do
        find("form[action='/admin/ad_platforms/#{ad_platform1.id}'] > input.delete-ad_platform-button").click
      end
      expect(page).to_not have_content(ad_platform1.name)
      expect(AdPlatform.where(id: ad_platform1.id).count).to eq(0)
    end
  end
end

