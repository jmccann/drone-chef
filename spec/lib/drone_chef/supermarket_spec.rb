require 'spec_helper'
require 'drone_chef/config'
require 'drone_chef/supermarket'

require 'stringio'

describe DroneChef::Supermarket do
  let(:server) { DroneChef::Supermarket.new build_data.to_json }
  let(:config) { server.instance_variable_get(:@config) }
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
        'user' => 'johndoe',
        'key' => 'PEMDATAHERE',
        'ssl_verify' => false
      }
    }
  end
  let(:file) { double('File') }
  let(:cookbook) do
    instance_double('Chef::Cookbook::Metadata', name: 'test_cookbook', version: '1.2.3')
  end

  let(:knife_show_shellout) do
    double('knife supermarket show test_cookbook',
           run_command: nil, stdout: 'Good output',
           stderr: 'ERROR: The object you are looking for could not be found', error?: false)
  end
  let(:knife_share_shellout) do
    double('knife supermarket share test_cookbook',
           run_command: nil, stdout: 'share output', stderr: 'share error', error?: false)
  end

  before do
    $stdout = StringIO.new
    $stderr = StringIO.new

    allow(Dir).to receive(:home).and_return '/root'

    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(true)
    allow(File).to receive(:exist?).with('/path/to/project/README.md').and_return(true)
    allow(server).to receive(:cookbook).and_return(cookbook)

    # Stub shell commands
    allow(Mixlib::ShellOut)
      .to receive(:new).with('knife supermarket share test_cookbook -c /root/.chef/knife.rb')
      .and_return(knife_share_shellout)
    allow(Mixlib::ShellOut)
      .to receive(:new).with('knife supermarket show test_cookbook 1.2.3 -c /root/.chef/knife.rb')
      .and_return(knife_show_shellout)
  end

  after do
    $stdout = STDOUT
    $stderr = STDERR
  end

  describe '#upload' do
    it 'logs that it is checking if cookbook has been uploaded' do
      server.upload
      expect($stdout.string).to match(%r{INFO: Checking if test_cookbook@1.2.3 is already shared to https://myserver.com})
    end

    it 'logs that cookbook was already uploaded' do
      # Defaults to test like cookbook was already uploaded
      server.upload
      expect($stdout.string).to match(%r{INFO: Cookbook test_cookbook version 1.2.3 already uploaded to https://myserver.com})
    end

    it 'does not log that cookbook was already uploaded if it was not' do
      allow(server).to receive(:knife_show).and_return(false) # Fake that cookbook was not uploaded
      server.upload
      expect($stdout.string).not_to match(/already uploaded/)
    end

    it 'checks if cookbook is already uploaded' do
      expect(knife_show_shellout).to receive(:run_command)
      server.upload
    end

    it 'shares cookbook to supermarket' do
      allow(server).to receive(:knife_show).and_return(false)
      expect(knife_share_shellout).to receive(:run_command)
      server.upload
    end

    it 'shows debug output when debug?' do
      allow(config).to receive(:debug?).and_return(true)
      allow(server).to receive(:knife_show).and_return(false) # Fake that cookbook was not uploaded
      server.upload
      expect($stdout.string).to match(/share output/)
    end

    it 'does not log debug output during upload' do
      allow(server).to receive(:knife_show).and_return(false) # Fake that cookbook was not uploaded
      server.upload
      expect($stdout.string).not_to match(/share output/)
    end

    it 'shows upload error' do
      allow(server).to receive(:knife_show).and_return(false) # Fake that cookbook was not uploaded
      allow(knife_share_shellout).to receive(:error?).and_return(true)
      expect { server.upload }.to raise_error('ERROR: Failed to upload cookbook')
      expect($stdout.string).to match(/share error/)
    end

    it 'does not share if already uploaded' do
      allow(server).to receive(:knife_show).and_return(true)
      expect(server).not_to receive(:upload_command)
      server.upload
    end
  end

  describe '#write_configs' do
    it 'writes common conigs' do
      allow(server).to receive(:write_knife_rb)
      expect(config).to receive(:write_configs)
      server.write_configs
    end

    it 'writes knife config' do
      allow(config).to receive(:write_configs)
      expect(FileUtils).to receive(:mkdir_p).with '/root/.chef'
      expect(File).to receive(:open).with('/root/.chef/knife.rb', 'w').and_yield(file)
      expect(file).to receive(:puts).with("node_name 'johndoe'")
      expect(file).to receive(:puts).with("client_key '/tmp/key.pem'")
      expect(file).to receive(:puts).with("cookbook_path '/path/to'")
      expect(file).to receive(:puts).with('ssl_verify_mode :verify_none')
      expect(file).to receive(:puts).with("knife[:supermarket_site] = 'https://myserver.com'")
      server.write_configs
    end
  end
end
