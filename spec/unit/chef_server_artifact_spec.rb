require "spec_helper"
require "cookbook-omnifetch/chef_server.rb"

RSpec.describe CookbookOmnifetch::ChefServerArtifactLocation do

  let(:http_client) { double("Http Client") }

  let(:test_root) { "/some/fake/path" }

  let(:storage_path) { File.join(test_root, "storage") }

  let(:dependency) { double("Dependency", name: cookbook_name) }

  let(:cookbook_name) { "example" }

  let(:cookbook_identifier) { "467dc855408ce8b74f991c5dc2fd72a6aa369b60" }

  let(:url) { "https://chef.example.com/organizations/example" }

  let(:options) { { chef_server_artifact: url, identifier: cookbook_identifier, http_client: http_client } }

  let(:expected_cache_key) { "example-467dc855408ce8b74f991c5dc2fd72a6aa369b60" }

  subject(:chef_server_artifact_location) { described_class.new(dependency, options) }

  before do
    allow(CookbookOmnifetch).to receive(:storage_path).and_return(Pathname.new(storage_path))
  end

  it "has a URI" do
    expect(chef_server_artifact_location.uri).to eq(url)
  end

  it "has an HTTP client" do
    expect(chef_server_artifact_location.http_client).to eq(http_client)
  end

  it "has a metadata_based_installer" do
    installer = chef_server_artifact_location.installer
    expect(installer).to be_a(CookbookOmnifetch::MetadataBasedInstaller)
    expect(installer.http_client).to eq(http_client)
    expect(installer.url_path).to eq("/cookbook_artifacts/example/467dc855408ce8b74f991c5dc2fd72a6aa369b60")
    expect(installer.install_path.to_s).to eq(File.join(storage_path, expected_cache_key))
  end

  it "has a cache key containing the site URI and version" do
    expect(chef_server_artifact_location.cache_key).to eq(expected_cache_key)
  end

  it "has an identifier" do
    expect(chef_server_artifact_location.cookbook_identifier).to eq(cookbook_identifier)
  end

  it "provides lock data as a Hash" do
    expected_data = {
      "chef_server" => url,
      "server_identifier" => cookbook_identifier,
    }
    expect(chef_server_artifact_location.lock_data).to eq(expected_data)
  end

  context "when using the default chef server HTTP client" do

    let(:options) { { chef_server_artifact: url, identifier: cookbook_identifier } }

    let(:default_http_client) { double("Http Client") }

    before do
      CookbookOmnifetch.integration.default_chef_server_http_client = default_http_client
    end

    after do
      CookbookOmnifetch.integration.default_chef_server_http_client = nil
    end

    it "uses the default http client for requests" do
      expect(chef_server_artifact_location.http_client).to eq(default_http_client)
    end

    context "and an http client is explicitly passed" do

      let(:options) { { chef_server: url, identifier: cookbook_identifier, http_client: http_client } }

      it "uses the explicitly passed client instead of the default" do
        expect(chef_server_artifact_location.http_client).to eq(http_client)
      end

    end
  end

  describe "when installing" do

    let(:installer) { instance_double("CookbookOmnifetch::MetadataBasedInstaller") }

    it "delegates to the MetadataBasedInstaller" do
      allow(chef_server_artifact_location).to receive(:installer).and_return(installer)
      expect(installer).to receive(:install)
      chef_server_artifact_location.install
    end

  end

end
