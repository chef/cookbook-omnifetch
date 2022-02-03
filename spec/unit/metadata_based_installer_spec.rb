require "spec_helper"
require "cookbook-omnifetch/metadata_based_installer"

RSpec.shared_context "sample_metadata" do

  let(:raw_metadata) do
    {
      "recipes" => [
        { "name" => "default.rb", "path" => "recipes/default.rb", "checksum" => "da97c94bb6acb2b7900cbf951654fea3", "specificity" => "default", "url" => "https://example.com/recipes/default.rb" },
      ],
      "root_files" => [
        { "name" => "metadata.rb", "path" => "metadata.rb", "checksum" => "eea518f9315141f07bec8278fb05688c", "specificity" => "default", "url" => "https://example.com/metadata.rb" },
      ],
    }

  end
end

RSpec.describe CookbookOmnifetch::MetadataBasedInstaller::CookbookMetadata do

  include_context "sample_metadata"

  subject(:cb_metadata) { described_class.new(raw_metadata) }

  it "yields a set of paths and urls" do
    expect { |b| cb_metadata.files(&b) }.to yield_successive_args(["https://example.com/recipes/default.rb", "recipes/default.rb", "da97c94bb6acb2b7900cbf951654fea3"],
                                                                  ["https://example.com/metadata.rb", "metadata.rb", "eea518f9315141f07bec8278fb05688c"])
  end
end

RSpec.describe CookbookOmnifetch::MetadataBasedInstaller do

  include_context "sample_metadata"

  let(:url_path) { "/cookbooks/example/0.5.0" }

  let(:http_client) do
    double("Http Client")
  end

  let(:recipe_url) do
    raw_metadata["recipes"][0]["url"]
  end

  let(:recipe_path) do
    raw_metadata["recipes"][0]["path"]
  end

  let(:recipe_filehandle) do
    File.open(File.join(remote_path, recipe_path))
  end

  let(:root_file_url) do
    raw_metadata["root_files"][0]["url"]
  end

  let(:root_file_path) do
    raw_metadata["root_files"][0]["path"]
  end

  let(:root_file_filehandle) do
    File.open(File.join(remote_path, root_file_path))
  end

  let(:cookbook_fixture_path) { fixtures_path.join("cookbooks/example_cookbook") }

  let(:test_root) { Dir.mktmpdir(nil) }

  let(:remote_path) { File.join(test_root, "remote") }

  let(:install_path) { File.join(test_root, "install_path") }

  let(:cookbook_files) { %w{metadata.rb recipes recipes/default.rb} }

  let(:expected_installed_files) do
    cookbook_files.map do |file|
      File.join(install_path, file)
    end
  end

  subject(:installer) do
    described_class.new(http_client: http_client,
                        url_path: url_path,
                        install_path: install_path)
  end

  before do
    FileUtils.cp_r(cookbook_fixture_path, remote_path)
  end

  after do
    FileUtils.rm_r(test_root)
  end

  describe "installing the cookbook" do
    before do
      expect(http_client).to receive(:get)
        .with(url_path)
        .and_return(raw_metadata)
      expect(http_client).to receive(:streaming_request)
        .with(recipe_url)
        .and_yield(recipe_filehandle)
      expect(http_client).to receive(:streaming_request)
        .with(root_file_url)
        .and_yield(root_file_filehandle)
    end

    it "installs the cookbook to the desired install path" do
      expect(Dir).to_not exist(install_path)
      installer.install
      expect(Dir).to exist(install_path)
      expect(Dir.glob("#{install_path}/**/*")).to match_array(expected_installed_files)
    end

    it "Removes extra files from the install path" do
      FileUtils.mkdir(install_path)
      File.write(File.join(install_path, "extra.rb"), "blah")
      installer.install
      expect(Dir.glob("#{install_path}/**/*")).to match_array(expected_installed_files)
    end

    context "when files are changed in place" do
      let(:content_digest) { "da97c94bb6acb2b7900cbf951654fea3" }
      it "replaces them with the right file" do
        corrupt_target = File.join(install_path, "recipes", "default.rb")
        FileUtils.mkdir_p(File.dirname(corrupt_target))
        File.write(corrupt_target, "This digest is no longer #{content_digest}")

        # Sanity check to prove to ourselves that the checksum is wrong.
        expect(installer.file_outdated?(corrupt_target, content_digest)).to be(true)

        installer.install # force the cache update

        # Will no longer report as outdated because it was replaced with the wrong one.
        expect(installer.file_outdated?(corrupt_target, content_digest)).to be(false)
      end
    end

  end

end
