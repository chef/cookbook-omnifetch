require 'spec_helper'
require 'cookbook-omnifetch/artifactserver'

module CookbookOmnifetch
  describe ArtifactserverLocation do

    let(:cookbook_name) { "nginx" }

    let(:cookbook_version) { "1.5.23" }

    let(:constraint) { double("Constraint") }

    let(:dependency) { double("Dependency", name: cookbook_name, constraint: constraint) }

    let(:url) { "https://supermarket.getchef.com/api/v1/cookbooks/nginx/versions/1.5.23/download" }

    let(:options) { {artifactserver: url, version: cookbook_version } }

    subject(:public_repo_location) { ArtifactserverLocation.new(dependency, options) }

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
      expected_install_path = Pathname.new('~/.berkshelf/cookbooks').expand_path.join("nginx-1.5.23-supermarket.getchef.com")
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
        "version" => "1.5.23"
      }
      expect(public_repo_location.lock_data).to eq(expected_data)
    end
  end
end

