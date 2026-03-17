class SeedLookupTables < ActiveRecord::Migration[8.1]
  def up
    # Organization Types
    [
      "Nonprofit",
      "For-profit",
      "Government",
      "Education",
      "Healthcare Provider",
      "Other",
    ].each_with_index do |name, i|
      OrganizationType.find_or_create_by!(name: name) { |r| r.position = i + 1 }
    end

    # Industries
    [
      "Ecommerce / Retail",
      "B2B SaaS",
      "B2B Services",
      "Healthcare",
      "Education",
      "Financial Services",
      "Media / Publishing",
      "Automotive and Transportation",
      "Consumer Packaged Goods (CPG)",
      "Education and Training",
      "Energy and Utilities",
      "Real Estate",
      "Legal Services",
      "Manufacturing",
      "Technology",
      "Hospitality and Travel",
      "Nonprofit",
      "Government",
      "Other",
    ].each_with_index do |name, i|
      Industry.find_or_create_by!(name: name) { |r| r.position = i + 1 }
    end

    # Primary Audiences
    [
      "Donors",
      "Members",
      "Patients",
      "Caregivers",
      "Volunteers",
      "Customers",
      "Prospects",
      "Other",
    ].each_with_index do |name, i|
      PrimaryAudience.find_or_create_by!(name: name) { |r| r.position = i + 1 }
    end

    # Tone Rules
    [
      "Supportive",
      "Urgent",
      "Clinical",
      "Optimistic",
      "Authoritative",
      "Conversational",
      "Other",
    ].each_with_index do |name, i|
      ToneRule.find_or_create_by!(name: name) { |r| r.position = i + 1 }
    end

    # Geographies
    [
      "United States",
      "North America",
      "Canada",
      "Europe",
      "Asia",
      "Australia",
      "Central America",
      "South America",
    ].each_with_index do |name, i|
      Geography.find_or_create_by!(name: name) { |r| r.position = i + 1 }
    end
  end

  def down
    OrganizationType.delete_all
    Industry.delete_all
    PrimaryAudience.delete_all
    ToneRule.delete_all
    Geography.delete_all
  end
end
