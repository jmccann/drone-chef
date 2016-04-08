require "spec_helper"
require "drone"

describe Drone::Chef::Config do
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
        "ssl_verify" => false
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
      allow(Dir).to receive(:home).and_return "/root"

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

  # let(:file) { double('File') }
  #
  # before do
  #   @original_stderr = $stderr
  #   @original_stdout = $stdout
  #
  #   # Redirect stderr and stdout
  #   $stderr = File.open(File::NULL, 'w')
  #   $stdout = File.open(File::NULL, 'w')
  #
  #   allow(Dir).to receive(:home).and_return '/root'
  # end
  #
  # after do
  #   $stderr = @original_stderr
  #   $stdout = @original_stdout
  # end
  #
  # describe '#workspace' do
  #   it 'returns the project workspace' do
  #     expect(config.workspace).to eq '/path/to/project'
  #   end
  # end
  #
  # describe '#server' do
  #   it 'returns the server' do
  #     expect(config.server).to eq 'https://myserver.com'
  #   end
  # end
  #
  # describe '#type' do
  #   it 'returns the default if not provided' do
  #     build_data['vargs'].delete 'type'
  #     expect(config.type).to eq 'supermarket'
  #   end
  #
  #   it 'returns the user value' do
  #     expect(config.type).to eq 'server'
  #   end
  # end
  #
  # describe '#user' do
  #   it 'returns the user' do
  #     expect(config.user).to eq 'jane'
  #   end
  # end
  #
  # describe '#key_path' do
  #   it 'returns the key_path' do
  #     expect(config.key_path).to eq '/tmp/key.pem'
  #   end
  # end
  #
  # describe '#ssl_verify' do
  #   it 'returns the default if not provided' do
  #     build_data['vargs'].delete 'ssl_verify'
  #     expect(config.ssl_verify).to eq true
  #   end
  #
  #   it 'returns the user value' do
  #     expect(config.ssl_verify).to eq false
  #   end
  # end
  #
  # describe '#ssl_verify_mode' do
  #   it 'returns the default if not provided' do
  #     build_data['vargs'].delete 'ssl_verify'
  #     expect(config.ssl_verify_mode).to eq ':verify_peer'
  #   end
  #
  #   it 'returns the user value' do
  #     expect(config.ssl_verify_mode).to eq ':verify_none'
  #   end
  # end
  #
  # describe '#write_configs' do
  #   it 'writes .netrc file' do
  #     allow(config).to receive(:write_key)
  #     expect(File).to receive(:open).with('/root/.netrc', 'w').and_yield(file)
  #     expect(file).to receive(:puts).with('machine the_machine')
  #     expect(file).to receive(:puts).with('  login johndoe')
  #     expect(file).to receive(:puts).with('  password test123')
  #     config.write_configs
  #   end
  #
  #   it 'writes key file' do
  #     allow(config).to receive(:write_netrc)
  #     expect(File).to receive(:open).with('/tmp/key.pem', 'w').and_yield(file)
  #     expect(file).to receive(:write).with('PEMDATAHERE')
  #     config.write_configs
  #   end
  # end
  #
  # describe '#debug?' do
  #   subject { config.debug? }
  #
  #   before do
  #     ENV['DEBUG'] = nil
  #   end
  #
  #   context 'environment is true and build is true' do
  #     before do
  #       ENV['DEBUG'] = 'true'
  #       build_data['vargs']['debug'] = true
  #     end
  #
  #     it { is_expected.to eq true }
  #   end
  #
  #   context 'environment is false and build is false' do
  #     before do
  #       ENV['DEBUG'] = 'false'
  #       build_data['vargs']['debug'] = false
  #     end
  #
  #     it { is_expected.to eq false }
  #   end
  #
  #   context 'environment is true and build is false' do
  #     before do
  #       ENV['DEBUG'] = 'true'
  #       build_data['vargs']['debug'] = false
  #     end
  #
  #     it { is_expected.to eq true }
  #   end
  #
  #   context 'environment is false and build is true' do
  #     before do
  #       ENV['DEBUG'] = 'false'
  #       build_data['vargs']['debug'] = true
  #     end
  #
  #     it { is_expected.to eq true }
  #   end
  #
  #   context 'environment is nil and build is nil' do
  #     it { is_expected.to eq false }
  #   end
  #
  #   context 'environment is nil and build is true' do
  #     before do
  #       build_data['vargs']['debug'] = true
  #     end
  #
  #     it { is_expected.to eq true }
  #   end
  #
  #   context 'environment is nil and build is false' do
  #     before do
  #       build_data['vargs']['debug'] = false
  #     end
  #
  #     it { is_expected.to eq false }
  #   end
  # end
end
