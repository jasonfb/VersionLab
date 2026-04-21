require 'rails_helper'

RSpec.describe ApplicationPolicy do
  let(:user) { create(:user) }
  let(:record) { create(:account) }
  let(:policy) { described_class.new(user, record) }

  it "denies index by default" do
    expect(policy.index?).to be false
  end

  it "denies show by default" do
    expect(policy.show?).to be false
  end

  it "denies create by default" do
    expect(policy.create?).to be false
  end

  it "delegates new? to create?" do
    expect(policy.new?).to eq(policy.create?)
  end

  it "denies update by default" do
    expect(policy.update?).to be false
  end

  it "delegates edit? to update?" do
    expect(policy.edit?).to eq(policy.update?)
  end

  it "denies destroy by default" do
    expect(policy.destroy?).to be false
  end

  describe ApplicationPolicy::Scope do
    it "raises when resolve is not defined" do
      scope = described_class.new(user, Account)
      expect { scope.resolve }.to raise_error(NoMethodError, /resolve/)
    end
  end
end
