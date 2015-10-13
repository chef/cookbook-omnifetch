require 'spec_helper'
require 'cookbook-omnifetch/exceptions'

module CookbookOmnifetch
  describe "Exceptions" do

    describe NotACookbook do

      subject(:exception) do
        described_class.new("/path/to/cookbook")
      end

      let(:message) do
        "The resource at '/path/to/cookbook' does not appear to be a valid cookbook. Does it have a metadata.rb?"
      end

      it "creates an informative error in #message" do
        expect(exception.message).to eq(message)
      end

      it "creates an informative error in #to_s" do
        expect(exception.to_s).to eq(message)
      end

    end

    describe CookbookValidationFailure do

      let(:dependency) { instance_double("ChefDK::Policyfile::CookbookLocationSpecification", to_s: "apt ~> 1.2.3") }

      # The exception class itself doesn't use this
      let(:cached_cookbook) { Object.new }

      subject(:exception) do
        described_class.new(dependency, cached_cookbook)
      end

      let(:message) do
        "The cookbook downloaded for apt ~> 1.2.3 did not satisfy the constraint."
      end

      it "creates an informative error in #message" do
        expect(exception.message).to eq(message)
      end

      it "creates an informative error in #to_s" do
        expect(exception.to_s).to eq(message)
      end

    end

    describe MismatchedCookbookName do

      let(:dependency) { instance_double("ChefDK::Policyfile::CookbookLocationSpecification", name: "apt") }

      let(:cached_cookbook) { instance_double("Chef::Cookbook", cookbook_name: "apt") }

      subject(:exception) do
        described_class.new(dependency, cached_cookbook)
      end

      let(:message) do
        <<-EOM
In your Berksfile, you have:

  cookbook 'apt'

But that cookbook is actually named 'apt'

This can cause potentially unwanted side-effects in the future.

NOTE: If you do not explicitly set the 'name' attribute in the metadata, the name of the directory will be used instead. This is often a cause of confusion for dependency solving.
EOM
      end

      it "creates an informative error in #message" do
        expect(exception.message).to eq(message)
      end

      it "creates an informative error in #to_s" do
        expect(exception.to_s).to eq(message)
      end

    end

  end
end
