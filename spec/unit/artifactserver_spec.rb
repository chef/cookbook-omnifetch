require "spec_helper"
require "cookbook-omnifetch/artifactserver"

module CookbookOmnifetch
  describe ArtifactserverLocation do

    let(:cookbook_name) { "nginx" }

    let(:cookbook_version) { "1.5.23" }

    let(:constraint) { double("Constraint") }

    let(:dependency) { double("Dependency", name: cookbook_name, constraint: constraint) }

    let(:url) { "https://supermarket.getchef.com/api/v1/cookbooks/nginx/versions/1.5.23/download" }

    let(:options) { { artifactserver: url, version: cookbook_version } }

    subject(:public_repo_location) { described_class.new(dependency, options) }

    it "has a URI" do
      expect(public_repo_location.uri).to eq(url)
    end

    it "has a repo host" do
      expect(public_repo_location.repo_host).to eq("supermarket.getchef.com")
    end

    it "has an exact version" do
      expect(public_repo_location.cookbook_version).to eq("1.5.23")
    end

    it "has a cache key containing the site URI and version" do
      expect(public_repo_location.cache_key).to eq("nginx-1.5.23-supermarket.getchef.com")
    end

    it "sets the install location as the cache path plus cache key" do
      expected_install_path = Pathname.new("~/.berkshelf/cookbooks").expand_path.join("nginx-1.5.23-supermarket.getchef.com")
      expect(public_repo_location.install_path).to eq(expected_install_path)
    end

    it "considers the cookbook installed if it exists in the main cache" do
      expect(public_repo_location.install_path).to receive(:exist?).and_return(true)
      expect(public_repo_location.installed?).to be true
    end

    it "considers the cookbook not installed if it doesn't exist in the main cache" do
      expect(public_repo_location.install_path).to receive(:exist?).and_return(false)
      expect(public_repo_location.installed?).to be false
    end

    it "provides lock data as a Hash" do
      expected_data = {
        "artifactserver" => url,
        "version" => "1.5.23",
      }
      expect(public_repo_location.lock_data).to eq(expected_data)
    end

    context "when asked to install a new cookbook" do

      let(:http_client) { double("Http Client") }

      let(:test_root) { Dir.mktmpdir(nil) }

      let(:storage_path) { File.join(test_root, "storage") }

      let(:cache_path) { File.join(test_root, "cache") }

      let(:cookbook_fixtures_path) { fixtures_path.join("cookbooks") }

      let(:cookbook_name) { "example_cookbook" }

      let(:cookbook_version) { "0.5.0" }

      let(:cookbook_tarball_handle) do
        gz_file_name = File.join(test_root, "input.gz")
        Dir.chdir(cookbook_fixtures_path) do
          Mixlib::Archive.archive_directory(cookbook_name, gz_file_name)
        end
        File.open(gz_file_name)
      end

      let(:cookbook_files) { %w{. .. .gitignore .kitchen.yml Berksfile Berksfile.lock metadata.rb README.md recipes} }

      before do
        allow(CookbookOmnifetch).to receive(:storage_path).and_return(Pathname.new(storage_path))
        allow(CookbookOmnifetch).to receive(:cache_path).and_return(cache_path)
        FileUtils.mkdir_p(storage_path)
      end

      after do
        FileUtils.rm_r(test_root)
      end

      it "installs the cookbook to the desired install path" do
        expect(public_repo_location).to receive(:http_client).and_return(http_client)
        expect(cookbook_tarball_handle).to receive(:close).and_call_original
        expect(http_client).to receive(:streaming_request).with(nil).and_yield(cookbook_tarball_handle)
        expect(public_repo_location).to receive(:validate_cached!)

        public_repo_location.install

        expect(File).to exist(public_repo_location.cache_path)
        expect(Dir).to exist(public_repo_location.install_path)
        expect(Dir.entries(public_repo_location.install_path)).to match_array(cookbook_files)
      end
    end
  end
end
