require "spec_helper"

describe Drone::Chef::Config do
  include FakeFS::SpecHelpers

  let(:valid_pkey) do
    OpenSSL::PKey::RSA.generate(2048).to_s
  end

  let(:options) do
    {
      server: "https://myserver.com",
      org: "test_org",
      user: "jane",
      private_key: valid_pkey,
      ssl_verify: false,
      freeze: false,
      recursive: false,
      berks_files: ["Berksfile", "Berksfile.another"]
    }
  end

  let(:file) { double("File") }

  let(:config) do
    Drone::Chef::Config.new options
  end

  before do
    allow(Dir).to receive(:home).and_return "/root"
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?)
      .with("/path/to/project/Berksfile")
      .and_return true
    allow(File).to receive(:exist?)
      .with("/path/to/project/Berksfile.another")
      .and_return true
  end

  after do
    FakeFS::FileSystem.clear
  end

  describe "#validate!" do
    it "fails if no user provided" do
      options.delete :user
      expect { config.validate! }.to raise_error "Missing 'user'"
    end

    it "fails if no private key is provided" do
      options.delete :private_key
      expect { config.validate! }.to raise_error "Missing CHEF_PRIVATE_KEY"
    end

    it "fails if private key is not a valid format" do
      reg_check = /Failed to load CHEF_PRIVATE_KEY provided starting with/
      options[:private_key] = "INVALIDPEMDATA"
      expect { config.validate! }.to raise_error(reg_check)
    end

    it "fails if no server URL is provided" do
      options.delete :server
      expect { config.validate! }.to raise_error "Missing 'server'"
    end

    it "does not throw an error if validation passes" do
      expect { config.validate! }.not_to raise_error
    end
  end

  describe "#configure!" do
    # it "writes .netrc file" do
    #   allow(config).to receive(:write_keyfile)
    #
    #   expect(File).to receive(:open).with("/root/.netrc", "w").and_yield(file)
    #   expect(file).to receive(:puts).with("machine the_machine")
    #   expect(file).to receive(:puts).with("  login johndoe")
    #   expect(file).to receive(:puts).with("  password test123")
    #
    #   config.configure!
    # end

    # it "does not write .netrc file on local build" do
    #   build_data["workspace"].delete "netrc"
    #
    #   allow(config).to receive(:write_keyfile)
    #
    #   expect(File).not_to receive(:open).with("/root/.netrc", "w")
    #
    #   config.configure!
    # end

    it "writes key file" do
      allow(config).to receive(:write_netrc)

      expect(File).to receive(:open).with("/tmp/key.pem", "w").and_yield(file)
      expect(file).to receive(:write).with(valid_pkey)

      config.configure!
    end
  end

  describe "#ssl_mode" do
    it "returns value to disable ssl verify in knife" do
      options[:ssl_verify] = false
      expect(config.ssl_mode).to eq ":verify_none"
    end

    it "returns value to enable ssl verify in knife" do
      options[:ssl_verify] = true
      expect(config.ssl_mode).to eq ":verify_peer"
    end
  end

  describe "#knife_config_path" do
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

  describe "#berks_config_path" do
    it "returns the file path" do
      FakeFS do
        expect(config.berks_config_path.to_s)
          .to eq "/root/.berkshelf/config.json"
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
end
