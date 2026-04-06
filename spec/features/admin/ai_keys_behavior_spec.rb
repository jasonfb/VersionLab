require 'rails_helper'

describe 'interaction for Admin::AiKeysController' do
  include HotGlue::ControllerHelper
  include ActionView::RecordIdentifier

  # HOTGLUE-SAVESTART
  # HOTGLUE-END
  
  let!(:ai_service1) {create(:ai_service)}

  let!(:ai_key1) {
    ai_key = create(:ai_key , 
                          ai_service: ai_service1, 
                          api_key:  FFaker::Lorem.paragraphs(10).join() )

    ai_key.save!
    ai_key
  }
  
  describe "index" do
    it "should show me the list" do
      visit admin_ai_keys_path
      expect(page).to have_content(ai_key1.ai_service.name)
      expect(page).to have_content(ai_key1.api_key)
    end
  end

  describe "new & create" do
    it "should create a new Ai Key" do
      visit admin_ai_keys_path
      click_link "New Ai Key"
      expect(page).to have_selector(:xpath, './/h3[contains(., "New Ai Key")]')
      ai_service_id_selector = find("[name='ai_key[ai_service_id]']").click 
      ai_service_id_selector.first('option', text: ai_service1.name).select_option
      new_api_key = FFaker::Lorem.paragraphs(1).join() 
      find("[name='ai_key[api_key]']").fill_in(with: new_api_key)
      click_button "Save"
      expect(page).to have_content("Successfully created")

       expect(page).to have_content(ai_service1.name)
      expect(page).to have_content(new_api_key)
    end
  end


  describe "edit & update" do
    it "should return an editable form" do
      visit admin_ai_keys_path
      find("a.edit-ai_key-button[href='/admin/ai_keys/#{ai_key1.id}/edit']").click

      expect(page).to have_content("Editing #{ai_key1.to_label.squish || "(no name)"}")
      ai_service_id_selector = find("[name='ai_key[ai_service_id]']").click 
      ai_service_id_selector.first('option', text: ai_service1.name).select_option
      new_api_key = FFaker::Lorem.paragraphs(1).join() 
      find("[name='ai_key[api_key]']").fill_in(with: new_api_key)
      click_button "Save"
      within("turbo-frame#admin__#{dom_id(ai_key1)} ") do
         expect(page).to have_content(ai_service1.name)
       expect(page).to have_content(new_api_key)
      end
    end
  end 

  describe "destroy" do
    it "should destroy" do
      visit admin_ai_keys_path
      accept_alert do
        find("form[action='/admin/ai_keys/#{ai_key1.id}'] > input.delete-ai_key-button").click
      end
      expect(page).to_not have_content(ai_key1.to_label)
      expect(AiKey.where(id: ai_key1.id).count).to eq(0)
    end
  end
end

