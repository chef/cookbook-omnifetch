require "spec_helper"
require "cookbook-omnifetch/metadata_based_installer.rb"

RSpec.shared_context "sample_metadata" do

  let(:raw_metadata) do
    {
      "recipes" => [
        { "name" => "default.rb", "path" => "recipes/default.rb", "checksum" => "a6be794cdd2eb44d38fdf17f792a0d0d", "specificity" => "default", "url" => "https://example.com/recipes/default.rb" },
      ],
      "root_files" => [
        { "name" => "metadata.rb", "path" => "metadata.rb", "checksum" => "5b346119e5e41ab99500608decac8dca", "specificity" => "default", "url" => "https://example.com/metadata.rb" },
      ],
    }

  end
end

RSpec.describe CookbookOmnifetch::MetadataBasedInstaller::CookbookMetadata do

  include_context "sample_metadata"

  subject(:cb_metadata) { described_class.new(raw_metadata) }

  it "yields a set of paths and urls" do
    expect { |b| cb_metadata.files(&b) }.to yield_successive_args(["https://example.com/recipes/default.rb", "recipes/default.rb"], ["https://example.com/metadata.rb", "metadata.rb"])
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

    expect(http_client).to receive(:get).
      with(url_path).
      and_return(raw_metadata)
    expect(http_client).to receive(:streaming_request).
      with(recipe_url).
      and_yield(recipe_filehandle)
    expect(http_client).to receive(:streaming_request).
      with(root_file_url).
      and_yield(root_file_filehandle)
  end

  after do
    FileUtils.rm_r(test_root)
  end

  it "installs the cookbook to the desired install path" do
    expect(Dir).to_not exist(install_path)

    installer.install

    expect(Dir).to exist(install_path)
    expect(Dir.glob("#{install_path}/**/*")).to match_array(expected_installed_files)
  end

end

