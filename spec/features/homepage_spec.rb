require 'rails_helper'

describe 'homepage', type: :feature do
  it 'can load' do
    visit '/'
    expect(page).to have_content('VERSION LAB')
  end
end