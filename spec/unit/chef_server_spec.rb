require "spec_helper"
require "cookbook-omnifetch/chef_server.rb"

module CookbookOmnifetch
  METADATA = {
    "recipes" => [
      { "name" => "default.rb", "path" => "recipes/default.rb", "checksum" => "a6be794cdd2eb44d38fdf17f792a0d0d", "specificity" => "default", "url" => "https://example.com/recipes/default.rb" },
    ],
    "root_files" => [
      { "name" => "metadata.rb", "path" => "metadata.rb", "checksum" => "5b346119e5e41ab99500608decac8dca", "specificity" => "default", "url" => "https://example.com/metadata.rb" },
    ],
  }

  describe CookbookMetadata do
    let(:cb_metadata) { CookbookMetadata.new(METADATA) }

    it "yields a set of paths and urls" do
      expect { |b| cb_metadata.files(&b) }.to yield_successive_args(["https://example.com/recipes/default.rb", "recipes/default.rb"], ["https://example.com/metadata.rb", "metadata.rb"])
    end
  end

  describe ChefServerLocation do

    let(:http_client) { double("Http Client") }

    let(:cb_metadata) { CookbookMetadata.new(METADATA) }

    let(:test_root) { Dir.mktmpdir(nil) }

    let(:storage_path) { File.join(test_root, "storage") }

    let(:cache_path) { File.join(test_root, "cache") }

    let(:constraint) { double("Constraint") }

    let(:dependency) { double("Dependency", name: cookbook_name, constraint: constraint) }

    let(:cookbook_name) { "example" }
    let(:cookbook_version) { "0.5.0" }

    let(:url) { "https://chef.example.com/organizations/example" }

    let(:cookbook_fixture_path) { fixtures_path.join("cookbooks/example_cookbook") }

    let(:remote_path) { File.join(test_root, "remote") }
    let(:options) { { chef_server: url, version: cookbook_version, http_client: http_client } }

    let(:cookbook_files) { %w{. .. metadata.rb recipes} }
    subject(:chef_server_location) { described_class.new(dependency, options) }

    before do
      allow(CookbookOmnifetch).to receive(:storage_path).and_return(Pathname.new(storage_path))
      allow(CookbookOmnifetch).to receive(:cache_path).and_return(cache_path)
      allow_any_instance_of(File).to receive(:close).and_return(true)
      FileUtils.cp_r(cookbook_fixture_path, remote_path)
      FileUtils.mkdir_p(storage_path)
    end

    after do
      FileUtils.rm_r(test_root)
    end

    it "has a URI" do
      expect(chef_server_location.uri).to eq(url)
    end

    it "has a cache key containing the site URI and version" do
      expect(chef_server_location.cache_key).to eq("example-0.5.0")
    end

    it "has an exact version" do
      expect(chef_server_location.cookbook_version).to eq("0.5.0")
    end

    it "installs the cookbook to the desired install path" do
      expect(http_client).to receive(:get).with("/cookbooks/example/0.5.0").and_return(METADATA)
      expect(http_client).to receive(:streaming_request).twice do |url, &block|
        path = url.split("/", 4)[3]
        path = File.join(remote_path, path)
        block.call(File.open(path))
      end

      chef_server_location.install

      expect(Dir).to exist(chef_server_location.install_path)
      expect(Dir.entries(chef_server_location.install_path)).to match_array(cookbook_files)
    end

    it "provides lock data as a Hash" do
      expected_data = {
        "chef_server" => url,
        "version" => "0.5.0",
      }
      expect(chef_server_location.lock_data).to eq(expected_data)
    end

  end
end
