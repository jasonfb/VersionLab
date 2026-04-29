require 'rails_helper'

describe 'interaction for Admin::AdShapesController' do
  include HotGlue::ControllerHelper
  include ActionView::RecordIdentifier

    # HOTGLUE-SAVESTART
  # HOTGLUE-END
  




  let!(:ad_shape1) {
    ad_shape = create(:ad_shape , 
                          name: FFaker::Movie.title, 
                          min_ratio: rand(1)*10000, 
                          max_ratio: rand(1)*10000, 
                          position: rand(100) )

    ad_shape.save!
    ad_shape
  }
  
  describe "index" do
    it "should show me the list" do
      visit admin_ad_shapes_path
      expect(page).to have_content(ad_shape1.name)
      expect(page).to have_content(ad_shape1.min_ratio)
      expect(page).to have_content(ad_shape1.max_ratio)
      expect(page).to have_content(ad_shape1.position)
    end
  end

  describe "new & create" do
    it "should create a new Ad Shape" do
      visit admin_ad_shapes_path
      click_link "New Ad Shape"
      expect(page).to have_selector(:xpath, './/h3[contains(., "New Ad Shape")]')
      new_name = FFaker::Movie.title 
      find("[name='ad_shape[name]']").fill_in(with: new_name)
      new_min_ratio = rand(10) 
      find("[name='ad_shape[min_ratio]']").fill_in(with: new_min_ratio)
      new_max_ratio = rand(10) 
      find("[name='ad_shape[max_ratio]']").fill_in(with: new_max_ratio)
      new_position = rand(10) 
      find("[name='ad_shape[position]']").fill_in(with: new_position)
      click_button "Save"
      expect(page).to have_content("Successfully created")

      expect(page).to have_content(new_name)
      expect(page).to have_content(new_min_ratio)
      expect(page).to have_content(new_max_ratio)
      expect(page).to have_content(new_position)
    end
  end


  describe "edit & update" do
    it "should return an editable form" do
      visit admin_ad_shapes_path
      find("a.edit-ad_shape-button[href='/admin/ad_shapes/#{ad_shape1.id}/edit']").click

      expect(page).to have_content("Editing #{ad_shape1.name.squish || "(no name)"}")
      new_name = FFaker::Movie.title 
      find("[name='ad_shape[name]']").fill_in(with: new_name)
      new_min_ratio = rand(10) 
      find("[name='ad_shape[min_ratio]']").fill_in(with: new_min_ratio)
      new_max_ratio = rand(10) 
      find("[name='ad_shape[max_ratio]']").fill_in(with: new_max_ratio)
      new_position = rand(10) 
      find("[name='ad_shape[position]']").fill_in(with: new_position)
      click_button "Save"
      within("turbo-frame#admin__#{dom_id(ad_shape1)} ") do
        expect(page).to have_content(new_name)
       expect(page).to have_content(new_min_ratio)
       expect(page).to have_content(new_max_ratio)
       expect(page).to have_content(new_position)
      end
    end
  end 

  describe "destroy" do
    it "should destroy" do
      visit admin_ad_shapes_path
      accept_alert do
        find("form[action='/admin/ad_shapes/#{ad_shape1.id}'] > input.delete-ad_shape-button").click
      end
      expect(page).to_not have_content(ad_shape1.name)
      expect(AdShape.where(id: ad_shape1.id).count).to eq(0)
    end
  end
end

