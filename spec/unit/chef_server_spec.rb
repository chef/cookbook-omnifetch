require "spec_helper"
require "cookbook-omnifetch/chef_server.rb"

RSpec.describe CookbookOmnifetch::ChefServerLocation do

  let(:http_client) { double("Http Client") }

  let(:test_root) { "/some/fake/path" }

  let(:storage_path) { File.join(test_root, "storage") }

  let(:dependency) { double("Dependency", name: cookbook_name) }

  let(:cookbook_name) { "example" }

  let(:cookbook_version) { "0.5.0" }

  let(:url) { "https://chef.example.com/organizations/example" }

  let(:options) { { chef_server: url, version: cookbook_version, http_client: http_client } }

  subject(:chef_server_location) { described_class.new(dependency, options) }

  before do
    allow(CookbookOmnifetch).to receive(:storage_path).and_return(Pathname.new(storage_path))
  end

  it "has a URI" do
    expect(chef_server_location.uri).to eq(url)
  end

  it "has an HTTP client" do
    expect(chef_server_location.http_client).to eq(http_client)
  end

  it "has a metadata_based_installer" do
    installer = chef_server_location.installer
    expect(installer).to be_a(CookbookOmnifetch::MetadataBasedInstaller)
    expect(installer.http_client).to eq(http_client)
    expect(installer.url_path).to eq("/cookbooks/example/0.5.0")
    expect(installer.install_path.to_s).to eq(File.join(storage_path, "example-0.5.0"))
  end

  it "has a cache key containing the site URI and version" do
    expect(chef_server_location.cache_key).to eq("example-0.5.0")
  end

  it "has an exact version" do
    expect(chef_server_location.cookbook_version).to eq("0.5.0")
  end

  it "provides lock data as a Hash" do
    expected_data = {
      "chef_server" => url,
      "version" => "0.5.0",
    }
    expect(chef_server_location.lock_data).to eq(expected_data)
  end

  describe "when installing" do

    let(:installer) { instance_double("CookbookOmnifetch::MetadataBasedInstaller") }

    it "delegates to the MetadataBasedInstaller" do
      allow(chef_server_location).to receive(:installer).and_return(installer)
      expect(installer).to receive(:install)
      chef_server_location.install
    end

  end

end
