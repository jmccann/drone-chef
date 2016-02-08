require 'spec_helper'
require 'drone_chef/drone'
require 'drone_chef/config'

describe DroneChef::Config do
  let(:config) { DroneChef::Config.new build_data.to_json }
  let(:drone) { config.instance_variable_get(:@drone) }
  let(:build_data) do
    {
      'workspace' => {
        'path' => '/path/to/project',
        'netrc' => {
          'machine' => 'the_machine',
          'login' => 'johndoe',
          'password' => 'test123'
        }
      },
      'vargs' => {
        'server' => 'https://myserver.com',
        'type' => 'server',
        'user' => 'jane',
        'key' => 'PEMDATAHERE',
        'ssl_verify' => false
      }
    }
  end
  let(:file) { double('File') }

  before do
    @original_stderr = $stderr
    @original_stdout = $stdout

    # Redirect stderr and stdout
    $stderr = File.open(File::NULL, 'w')
    $stdout = File.open(File::NULL, 'w')
  end

  after do
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  describe '#workspace' do
    it 'returns the project workspace' do
      expect(config.workspace).to eq '/path/to/project'
    end
  end

  describe '#server' do
    it 'returns the server' do
      expect(config.server).to eq 'https://myserver.com'
    end
  end

  describe '#type' do
    it 'returns the default if not provided' do
      build_data['vargs'].delete 'type'
      expect(config.type).to eq 'supermarket'
    end

    it 'returns the user value' do
      expect(config.type).to eq 'server'
    end
  end

  describe '#user' do
    it 'returns the user' do
      expect(config.user).to eq 'jane'
    end
  end

  describe '#key_path' do
    it 'returns the key_path' do
      expect(config.key_path).to eq '/tmp/key.pem'
    end
  end

  describe '#ssl_verify' do
    it 'returns the default if not provided' do
      build_data['vargs'].delete 'ssl_verify'
      expect(config.ssl_verify).to eq true
    end

    it 'returns the user value' do
      expect(config.ssl_verify).to eq false
    end
  end

  describe '#ssl_verify_mode' do
    it 'returns the default if not provided' do
      build_data['vargs'].delete 'ssl_verify'
      expect(config.ssl_verify_mode).to eq ':verify_peer'
    end

    it 'returns the user value' do
      expect(config.ssl_verify_mode).to eq ':verify_none'
    end
  end

  describe '#write_configs' do
    it 'writes netrc' do
      allow(config).to receive(:write_key)
      expect(drone).to receive(:write_configs)
      config.write_configs
    end

    it 'writes key file' do
      allow(drone).to receive(:write_configs)
      expect(File).to receive(:open).with('/tmp/key.pem', 'w').and_yield(file)
      expect(file).to receive(:write).with('PEMDATAHERE')
      config.write_configs
    end
  end
end
