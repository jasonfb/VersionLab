require 'rails_helper'

describe 'interaction for Admin::AdPlatformSizesController' do
  include HotGlue::ControllerHelper
  include ActionView::RecordIdentifier

  # HOTGLUE-SAVESTART
  # HOTGLUE-END
  




  let!(:ad_platform_size1) {
    ad_platform_size = create(:ad_platform_size, ad_platform: ad_platform , 
                          name: FFaker::Movie.title, 
                          width: rand(100), 
                          height: rand(100), 
                          position: rand(100) )

    ad_platform_size.save!
    ad_platform_size
  }
  let(:ad_platform) {create(:ad_platform , : current_user )}
  
  describe "index" do
    it "should show me the list" do
      visit admin_ad_platform_ad_platform_sizes_path(ad_platform)
      expect(page).to have_content(ad_platform_size1.name)
      expect(page).to have_content(ad_platform_size1.width)
      expect(page).to have_content(ad_platform_size1.height)
      expect(page).to have_content(ad_platform_size1.position)
    end
  end

  describe "new & create" do
    it "should create a new Ad Platform Size" do
      visit admin_ad_platform_ad_platform_sizes_path(ad_platform)
      click_link "New Ad Platform Size"
      expect(page).to have_selector(:xpath, './/h3[contains(., "New Ad Platform Size")]')
      new_name = FFaker::Movie.title 
      find("[name='ad_platform_size[name]']").fill_in(with: new_name)
      new_width = rand(10) 
      find("[name='ad_platform_size[width]']").fill_in(with: new_width)
      new_height = rand(10) 
      find("[name='ad_platform_size[height]']").fill_in(with: new_height)
      new_position = rand(10) 
      find("[name='ad_platform_size[position]']").fill_in(with: new_position)
      click_button "Save"
      expect(page).to have_content("Successfully created")

      expect(page).to have_content(new_name)
      expect(page).to have_content(new_width)
      expect(page).to have_content(new_height)
      expect(page).to have_content(new_position)
    end
  end


  describe "edit & update" do
    it "should return an editable form" do
      visit admin_ad_platform_ad_platform_sizes_path(ad_platform)
      find("a.edit-ad_platform_size-button[href='/admin/ad_platform_sizes/#{ad_platform_size1.id}/edit']").click

      expect(page).to have_content("Editing #{ad_platform_size1.name.squish || "(no name)"}")
      new_name = FFaker::Movie.title 
      find("[name='ad_platform_size[name]']").fill_in(with: new_name)
      new_width = rand(10) 
      find("[name='ad_platform_size[width]']").fill_in(with: new_width)
      new_height = rand(10) 
      find("[name='ad_platform_size[height]']").fill_in(with: new_height)
      new_position = rand(10) 
      find("[name='ad_platform_size[position]']").fill_in(with: new_position)
      click_button "Save"
      within("turbo-frame#admin__#{dom_id(ad_platform_size1)} ") do
        expect(page).to have_content(new_name)
       expect(page).to have_content(new_width)
       expect(page).to have_content(new_height)
       expect(page).to have_content(new_position)
      end
    end
  end 

  describe "destroy" do
    it "should destroy" do
      visit admin_ad_platform_ad_platform_sizes_path(ad_platform)
      accept_alert do
        find("form[action='/admin/ad_platforms/#{ad_platform.id}/ad_platform_sizes/#{ad_platform_size1.id}'] > input.delete-ad_platform_size-button").click
      end
      expect(page).to_not have_content(ad_platform_size1.name)
      expect(AdPlatformSize.where(id: ad_platform_size1.id).count).to eq(0)
    end
  end
end

