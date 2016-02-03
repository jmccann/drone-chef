require 'spec_helper'
require 'drone_chef/config'
require 'drone_chef/supermarket'

describe DroneChef::Supermarket do
  let(:server) { DroneChef::Supermarket.new config }
  let(:config) do
    instance_double('DroneChef::Config', workspace: '/path/to/project',
                                         write_configs: nil, ssl_verify: false,
                                         knife_rb: '/root/.chef/knife.rb',
                                         server: 'https://myserver.com', user: 'johndoe',
                                         key_path: '/tmp/key.pem', ssl_verify_mode: ':verify_none',
                                         debug?: false)
  end
  let(:file) { double('File') }
  let(:process_status) { instance_double('Process::Status', success?: true) }
  let(:cookbook) do
    instance_double('Chef::Cookbook::Metadata', name: 'test_cookbook', version: '1.2.3')
  end

  let(:knife_show_shellout) do
    double('knife supermarket show test_cookbook',
           run_command: nil, stdout: '00:00', error?: false)
  end
  let(:knife_share_shellout) do
    double('knife supermarket share test_cookbook',
           run_command: nil, stdout: '00:00', error?: false)
  end

  before do
    @original_stderr = $stderr
    @original_stdout = $stdout

    # Redirect stderr and stdout
    $stderr = File.open(File::NULL, 'w')
    $stdout = File.open(File::NULL, 'w')

    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(true)
    allow(File).to receive(:exist?).with('/path/to/project/README.md').and_return(true)
    allow(server).to receive(:process_last_status).and_return(process_status)
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
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  describe '#upload' do
    it 'checks if cookbook is already uploaded' do
      expect(knife_show_shellout).to receive(:run_command)
      server.upload
    end

    it 'shares cookbook to supermarket' do
      allow(server).to receive(:knife_show).and_return(false)
      expect(knife_share_shellout).to receive(:run_command)
      server.upload
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
