require "spec_helper"
require "cookbook-omnifetch/staging_area"

RSpec.configure do |rspec|
  rspec.shared_context_metadata_behavior = :apply_to_host_groups
end

RSpec.describe CookbookOmnifetch::StagingArea do
  # Create a work area on the file system for setting up tests and clean it up
  # after each test.
  let(:test_area) { Pathname(Dir.mktmpdir(nil, Dir.tmpdir)) }
  after do
    FileUtils.rm_r(test_area)
  end
  let(:test_area_tmp) { test_area }

  # Make Dir.mktmpdir allocate temporary directories in the test area so that
  # they get cleaned up with the rest of the test area.
  before do
    allow(Dir).to receive(:mktmpdir).and_call_original
    allow(Dir).to receive(:mktmpdir).with(no_args) do
      Dir.mktmpdir("fake_tmpdir", test_area)
    end
  end

  let(:cache_path)  { test_area.join("fake_cache") }
  let(:target_path) { test_area.join("fake_cache", "fake_cookbook-1.2.3") }

  let(:cookbook_fixture_path) do
    fixtures_path.join("cookbooks", "example_cookbook")
  end
  def populate_from_fixture(dest_path)
    dest_path.parent.mkpath
    FileUtils.cp_r("#{cookbook_fixture_path}/.", dest_path)
  end

  let(:staging_area) { described_class.new }

  describe("::stage") do
    before do
      allow(described_class).to receive(:new).and_return(staging_area)
    end

    it "publishes the staging area when it contains updates" do
      expect(staging_area).to receive(:publish!)
      described_class.stage(target_path) do |path|
        populate_from_fixture(path)
      end
    end

    it "does not publish the staging area when it has no updates" do
      expect(staging_area).to_not receive(:publish!)
      described_class.stage(target_path) { |_path| }
    end

    it "cleans up the staging area when the block raises an exception" do
      expect(staging_area).to receive(:discard!)
      expect do
        described_class.stage(target_path) do |_path|
          raise "FAKE ERROR"
        end
      end.to raise_exception("FAKE ERROR")
    end
  end

  describe("#unavailable?") do
    it "is initially false" do
      expect(staging_area).to_not be_unavailable
    end
  end

  describe("#empty?") do
    it "is true when the staging area does not contain files" do
      expect(staging_area).to be_empty
    end

    it "is true when the staging area is removed from the file system" do
      staging_area.path.unlink

      expect(staging_area).to be_empty
    end

    it "is false when the staging area contains a file" do
      staging_area.path.join("test_file").write("TEST CONTENT")

      expect(staging_area).to_not be_empty
    end
  end

  describe("#path") do
    it "returns a Pathname" do
      expect(staging_area.path).to be_a(Pathname)
    end

    it "returns the path to a folder" do
      expect(staging_area.path).to be_directory
    end

    it "returns the same staging area when called twice" do
      expect(staging_area.path).to eq(staging_area.path)
    end

    it "provides a staging area in the temporary directory" do
      expect(staging_area.path.to_s).to start_with(test_area_tmp.to_s)
    end

    # Temporary directories have restrictive permissions not suitable for
    # the local cache.
    it "provides a staging area with regular permissions" do
      # test_area was created by mktmpdir and has restrictive permissions.
      tmp_perms = File::Stat.new(test_area).mode

      regular_dir = test_area.join("regular_dir")
      regular_dir.mkdir
      default_perms = File::Stat.new(regular_dir).mode

      # Don't produce a false success if run with a umask of 077.
      msg = "umask is too restrictive to perform this test"
      skip(msg) if default_perms == tmp_perms

      expect(File::Stat.new(staging_area.path).mode.to_s(8))
        .to eq(default_perms.to_s(8))
    end
  end

  describe("#match?") do
    it "is true when target contains an identical cookbooks" do
      populate_from_fixture(target_path)
      populate_from_fixture(staging_area.path)

      expect(staging_area).to be_match(target_path)
    end

    it "is false when the staging area does not exist" do
      populate_from_fixture(target_path)
      staging_area.path.unlink
      expect(staging_area).to_not be_match(target_path)
    end

    it "is false when staging has content and" +
      " the cache directory does not exist" do
        populate_from_fixture(staging_area.path)

        expect(staging_area).to_not be_match(target_path)
      end

    it "is false when the staging area has a recipe not in the target" do
      populate_from_fixture(target_path)
      populate_from_fixture(staging_area.path)
      file = staging_area.path.join("recipes", "panna_cotta.rb")
      file.write("# apply a tart berry glaze")

      expect(staging_area).to_not be_match(target_path)
    end

    it "is false when the staging area is missing a dot-file from the target" do
      populate_from_fixture(target_path)
      populate_from_fixture(staging_area.path)
      staging_area.path.join(".gitignore").unlink

      expect(staging_area).to_not be_match(target_path)
    end

    it "is false when README.md has a different file type than in the target" do
      populate_from_fixture(target_path)
      populate_from_fixture(staging_area.path)
      file_path = staging_area.path.join("README.md")
      file_path.unlink
      file_path.mkdir

      expect(staging_area).to_not be_match(target_path)
    end

    it "is false when README.md has different content" do
      populate_from_fixture(target_path)
      populate_from_fixture(staging_area.path)
      file_path = staging_area.path.join("README.md")
      expect(file_path).to exist
      file_path.write("this is not the file you are looking for")

      expect(staging_area).to_not be_match(target_path)
    end
  end

  describe("#discard!") do
    it "removes the temporary directory that held the staging area" do
      staging_area.path

      staging_area.discard!

      expect(test_area).to be_empty
    end

    it "makes the staging area unavailble" do
      staging_area.discard!

      expect(staging_area).to be_unavailable
    end
  end

  describe("#publish!") do
    it "creates the cache directory when it does not exist" do
      expect(cache_path).to_not exist

      staging_area.publish!(target_path)

      expect(cache_path).to exist
    end

    it "uses the cache directory if it already exists" do
      other_cookbook = cache_path.join("other_cookbook-0.0.1")
      populate_from_fixture(other_cookbook)

      staging_area.publish!(target_path)

      expect(other_cookbook).to exist
    end

    it "copies files from the staging area to the target" do
      populate_from_fixture(staging_area.path)

      staging_area.publish!(target_path)

      expect(target_path.join("recipes", "default.rb")).to exist
      expect(staging_area.path.join("recipes", "default.rb")).to exist
    end

    it "replaces the target directory if it already exists" do
      populate_from_fixture(staging_area.path)
      target_path.mkpath
      orig_inode = File::Stat.new(target_path).ino

      staging_area.publish!(target_path)

      expect(File::Stat.new(target_path).ino).to_not eq(orig_inode)
    end

    it "replaces the target near-atomically" do
      # Near-atomic replacement of the target is an important part of
      # StagingArea's contract.  Rspec cannot reliably test whether an operation
      # is performs atomically, so the only way this test can verify that the
      # requirement is met is to check that it is implemented in a specific way.
      # :(

      populate_from_fixture(staging_area.path)
      populate_from_fixture(target_path)

      # Directory renames are atomic file system operations when the source and
      # destination reside on the same file system.  Ensure that the destination
      # when moving the old release out of the way, and the source when moving
      # the new release into place are located somewhere under the parent
      # directory of the target.
      expect(File).to receive(:rename)
        .with(target_path, start_with(target_path.parent.to_s)).ordered
      expect(File).to receive(:rename)
        .with(start_with(target_path.parent.to_s), target_path).ordered
      staging_area.publish!(target_path)
    end
  end

  context "when the staging area is not available" do
    before do
      staging_area.discard!
    end

    it "#unavailable? is true" do
      expect(staging_area).to be_unavailable
    end

    it "#empty? raises StagingAreaNotAvailable" do
      expect { staging_area.empty? }
        .to raise_exception(CookbookOmnifetch::StagingAreaNotAvailable)
    end

    it "#match? raises StagingAreaNotAvailable" do
      expect { staging_area.match?(target_path) }
        .to raise_exception(CookbookOmnifetch::StagingAreaNotAvailable)
    end

    it "#path raises StagingAreaNotAvailable" do
      expect { staging_area.path }
        .to raise_exception(CookbookOmnifetch::StagingAreaNotAvailable)
    end

    it "#publish! raises StagingAreaNotAvailable" do
      expect { staging_area.publish!(target_path) }
        .to raise_exception(CookbookOmnifetch::StagingAreaNotAvailable)
    end

    it "#discard! does not raise an error" do
      expect { staging_area.discard! }
        .to_not raise_exception
    end
  end
end
