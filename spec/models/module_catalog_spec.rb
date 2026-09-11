require "rails_helper"

RSpec.describe ModuleCatalog do
  describe ".exists?" do
    it "accepts the base key and any catalogue feature key" do
      expect(ModuleCatalog.exists?("base")).to be true
      expect(ModuleCatalog.exists?("clients")).to be true
      expect(ModuleCatalog.exists?("bogus")).to be false
    end
  end

  describe ".permissions_for" do
    it "always returns every permission, ignoring its argument" do
      expect(ModuleCatalog.permissions_for(%w[clients])).to eq(ModuleCatalog::ALL_PERMISSIONS)
      expect(ModuleCatalog.permissions_for(nil)).to eq(ModuleCatalog::ALL_PERMISSIONS)
      expect(ModuleCatalog.permissions_for([])).to eq(ModuleCatalog::ALL_PERMISSIONS)
    end
  end

  it "combines the base permissions with every feature's permissions" do
    expect(ModuleCatalog::ALL_PERMISSIONS).to include(*ModuleCatalog::BASE_PERMISSIONS)

    ModuleCatalog::CATALOG.each_value do |feature|
      next if feature[:permissions].empty?

      expect(ModuleCatalog::ALL_PERMISSIONS).to include(*feature[:permissions])
    end
  end
end
