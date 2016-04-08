require "spec_helper"
require "drone"

describe Drone::Chef::Config do
  include FakeFS::SpecHelpers

  let(:build_data) do
    {
      "workspace" => {
        "path" => "/path/to/project",
        "netrc" => {
          "machine" => "the_machine",
          "login" => "johndoe",
          "password" => "test123"
        }
      },
      "vargs" => {
        "server" => "https://myserver.com",
        "type" => "server",
        "user" => "jane",
        "private_key" => "PEMDATAHERE",
        "ssl_verify" => false,
        "freeze" => false,
        "recursive" => false
      }
    }
  end

  let(:file) { double("File") }

  let(:payload) do
    p = Drone::Plugin.new build_data.to_json
    p.parse
    p.result
  end

  let(:config) do
    Drone::Chef::Config.new payload
  end

  before do
    allow(Dir).to receive(:home).and_return "/root"
  end

  describe '#validate!' do
    it "fails if no vargs are provided" do
      build_data.delete "vargs"
      expect { config.validate! }.to raise_error "No plugin data found"
    end

    it "fails if no user provided" do
      build_data["vargs"].delete "user"
      expect { config.validate! }.to raise_error "Please provide a username"
    end

    it "fails if no private_key is provided" do
      build_data["vargs"].delete "private_key"
      expect { config.validate! }.to raise_error "Please provide a private key"
    end

    it "fails if no server URL is provided" do
      build_data["vargs"].delete "server"
      expect { config.validate! }.to raise_error "Please provide a server URL"
    end

    it "does not throw an error if validation passes" do
      expect { config.validate! }.not_to raise_error
    end
  end

  describe '#configure!' do
    it "writes .netrc file" do
      allow(config).to receive(:write_keyfile)

      expect(File).to receive(:open).with("/root/.netrc", "w").and_yield(file)
      expect(file).to receive(:puts).with("machine the_machine")
      expect(file).to receive(:puts).with("  login johndoe")
      expect(file).to receive(:puts).with("  password test123")

      config.configure!
    end

    it "writes key file" do
      allow(config).to receive(:write_netrc)

      expect(File).to receive(:open).with("/tmp/key.pem", "w").and_yield(file)
      expect(file).to receive(:write).with("PEMDATAHERE")

      config.configure!
    end
  end

  describe '#ssl_mode' do
    it "returns value to disable ssl verify in knife" do
      build_data["vargs"]["ssl_verify"] = false
      expect(config.ssl_mode).to eq ":verify_none"
    end

    it "returns value to enable ssl verify in knife" do
      build_data["vargs"]["ssl_verify"] = true
      expect(config.ssl_mode).to eq ":verify_peer"
    end
  end

  describe '#ssl_verify?' do
    it "returns true by default" do
      build_data["vargs"].delete "ssl_verify"
      expect(config.ssl_verify?).to eq true
    end

    it "returns true from user" do
      build_data["vargs"]["ssl_verify"] = true
      expect(config.ssl_verify?).to eq true
    end

    it "returns false from user" do
      build_data["vargs"]["ssl_verify"] = false
      expect(config.ssl_verify?).to eq false
    end
  end

  describe '#freeze?' do
    it "returns true by default" do
      build_data["vargs"].delete "freeze"
      expect(config.freeze?).to eq true
    end

    it "returns true from user" do
      build_data["vargs"]["freeze"] = true
      expect(config.freeze?).to eq true
    end

    it "returns false from user" do
      build_data["vargs"]["freeze"] = false
      expect(config.freeze?).to eq false
    end
  end

  describe '#recursive?' do
    it "returns true by default" do
      build_data["vargs"].delete "recursive"
      expect(config.recursive?).to eq true
    end

    it "returns true from user" do
      build_data["vargs"]["recursive"] = true
      expect(config.recursive?).to eq true
    end

    it "returns false from user" do
      build_data["vargs"]["recursive"] = false
      expect(config.recursive?).to eq false
    end
  end

  describe '#knife_config_path' do
    it "returns the file path" do
      FakeFS do
        expect(config.knife_config_path.to_s).to eq "/root/.chef/knife.rb"
      end
    end

    it "creates the directory structure if it doesn't exist" do
      FakeFS do
        # Test that it does not exist yet
        expect(Dir.exist?("/root/.chef")).to eq false

        # Run the code
        config.knife_config_path

        # Test that it exists now
        expect(Dir.exist?("/root/.chef")).to eq true
      end
    end
  end

  describe '#berks_config_path' do
    it "returns the file path" do
      FakeFS do
        expect(config.berks_config_path.to_s).to eq "/root/.berkshelf/config.json"
      end
    end

    it "creates the directory structure if it doesn't exist" do
      FakeFS do
        # Test that it does not exist yet
        expect(Dir.exist?("/root/.berkshelf")).to eq false

        # Run the code
        config.berks_config_path

        # Test that it exists now
        expect(Dir.exist?("/root/.berkshelf")).to eq true
      end
    end
  end

  describe '#debug?' do
    subject { config.debug? }

    before do
      ENV["DEBUG"] = nil
    end

    context "environment is true and build is true" do
      before do
        ENV["DEBUG"] = "true"
        build_data["vargs"]["debug"] = true
      end

      it { is_expected.to eq true }
    end

    context "environment is false and build is false" do
      before do
        ENV["DEBUG"] = "false"
        build_data["vargs"]["debug"] = false
      end

      it { is_expected.to eq false }
    end

    context "environment is true and build is false" do
      before do
        ENV["DEBUG"] = "true"
        build_data["vargs"]["debug"] = false
      end

      it { is_expected.to eq true }
    end

    context "environment is false and build is true" do
      before do
        ENV["DEBUG"] = "false"
        build_data["vargs"]["debug"] = true
      end

      it { is_expected.to eq true }
    end

    context "environment is nil and build is nil" do
      it { is_expected.to eq false }
    end

    context "environment is nil and build is true" do
      before do
        build_data["vargs"]["debug"] = true
      end

      it { is_expected.to eq true }
    end

    context "environment is nil and build is false" do
      before do
        build_data["vargs"]["debug"] = false
      end

      it { is_expected.to eq false }
    end
  end
end
