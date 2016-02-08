require 'spec_helper'
require 'drone_chef/drone'

describe DroneChef::Drone do
  let(:drone) { DroneChef::Drone.new build_data.to_json }
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
        'user' => 'jane',
        'key' => 'PEMDATAHERE'
      }
    }
  end
  let(:file) { double('File') }

  before do
    allow(Dir).to receive(:home).and_return('/root')
  end

  describe '#write_configs' do
    it 'writes .netrc file' do
      expect(File).to receive(:open).with('/root/.netrc', 'w').and_yield(file)
      expect(file).to receive(:puts).with('machine the_machine')
      expect(file).to receive(:puts).with('  login johndoe')
      expect(file).to receive(:puts).with('  password test123')
      drone.write_configs
    end
  end

  describe '#plugin_args' do
    it 'returns plugin arguments' do
      expect(drone.plugin_args).to eq build_data['vargs']
    end
  end

  describe '#debug?' do
    subject { drone.debug? }

    before do
      ENV['DEBUG'] = nil
    end

    context 'environment is true and build is true' do
      before do
        ENV['DEBUG'] = 'true'
        build_data['vargs']['debug'] = true
      end

      it { is_expected.to eq true }
    end

    context 'environment is false and build is false' do
      before do
        ENV['DEBUG'] = 'false'
        build_data['vargs']['debug'] = false
      end

      it { is_expected.to eq false }
    end

    context 'environment is true and build is false' do
      before do
        ENV['DEBUG'] = 'true'
        build_data['vargs']['debug'] = false
      end

      it { is_expected.to eq true }
    end

    context 'environment is false and build is true' do
      before do
        ENV['DEBUG'] = 'false'
        build_data['vargs']['debug'] = true
      end

      it { is_expected.to eq true }
    end

    context 'environment is nil and build is nil' do
      it { is_expected.to eq false }
    end

    context 'environment is nil and build is true' do
      before do
        build_data['vargs']['debug'] = true
      end

      it { is_expected.to eq true }
    end

    context 'environment is nil and build is false' do
      before do
        build_data['vargs']['debug'] = false
      end

      it { is_expected.to eq false }
    end
  end
end
