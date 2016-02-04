require 'spec_helper'
require 'drone_chef/config'
require 'drone_chef/chef_server'

describe DroneChef::ChefServer do
  let(:server) { DroneChef::ChefServer.new config }
  let(:config) do
    instance_double('DroneChef::Config', plugin_args: plugin_args, workspace: '/path/to/project',
                                         write_configs: nil, ssl_verify: false,
                                         knife_rb: '/root/.chef/knife.rb', user: 'johndoe',
                                         key_path: '/tmp/key.pem', server: 'https://myserver.com',
                                         ssl_verify_mode: ':verify_none', debug?: false)
  end

  let(:plugin_args) do
    {
      'org' => 'my_chef_org',
      'recursive' => false,
      'freeze' => false
    }
  end
  let(:file) { double('File') }
  let(:cookbook) do
    instance_double('Chef::Cookbook::Metadata', name: 'test_cookbook', version: '1.2.3')
  end

  let(:berks_install_shellout) do
    double('berks install',
           run_command: nil, stdout: 'berks_install_stdout', stderr: 'berks_install_stderr', error?: false)
  end
  let(:berks_upload_shellout) do
    double('berks upload',
           run_command: nil, stdout: 'berks_upload_stdout', stderr: 'berks_upload_stderr', error?: false)
  end
  let(:knife_upload_shellout) do
    double('knife upload',
           run_command: nil, stdout: 'knife_upload_stdout', stderr: 'knife_upload_stderr', error?: false)
  end

  before do
    @original_stderr = $stderr
    @original_stdout = $stdout

    # Redirect stderr and stdout
    $stderr = File.open(File::NULL, 'w')
    $stdout = File.open(File::NULL, 'w')

    allow(File).to receive(:exist?).and_call_original
    allow(Dir).to receive(:exist?).and_call_original

    # Shell command stubbing
    allow(Mixlib::ShellOut)
      .to receive(:new).with('berks install -b /path/to/project/Berksfile')
      .and_return(berks_install_shellout)
    allow(Mixlib::ShellOut)
      .to receive(:new).with('berks upload -b /path/to/project/Berksfile')
      .and_return(berks_upload_shellout)
    allow(Mixlib::ShellOut)
      .to receive(:new).with('knife upload . -c /root/.chef/knife.rb')
      .and_return(knife_upload_shellout)
  end

  after do
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  describe '#recursive' do
    it 'returns the default if not provided' do
      plugin_args.delete 'recursive'
      expect(server.recursive).to eq true
    end

    it 'returns the user value' do
      expect(server.recursive).to eq false
    end
  end

  describe '#freeze' do
    it 'returns the default if not provided' do
      plugin_args.delete 'freeze'
      expect(server.freeze).to eq true
    end

    it 'returns the user value' do
      expect(server.freeze).to eq false
    end
  end

  describe '#berksfile?' do
    it 'returns true if Berksfile exists' do
      allow(File).to receive(:exist?).with('/path/to/project/Berksfile').and_return(true)
      allow(File).to receive(:exist?).with('/path/to/project/Berksfile.lock').and_return(false)
      expect(server.berksfile?).to eq true
    end

    it 'returns true if Berksfile.lock exists' do
      allow(File).to receive(:exist?).with('/path/to/project/Berksfile').and_return(false)
      allow(File).to receive(:exist?).with('/path/to/project/Berksfile.lock').and_return(true)
      expect(server.berksfile?).to eq true
    end

    it 'returns false if metadata.rb does not exist' do
      allow(File).to receive(:exist?).with('/path/to/project/Berksfile').and_return(false)
      allow(File).to receive(:exist?).with('/path/to/project/Berksfile.lock').and_return(false)
      expect(server.berksfile?).to eq false
    end
  end

  describe '#cookbook?' do
    it 'returns true if metadata.rb exists' do
      allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(true)
      expect(server.cookbook?).to eq true
    end

    it 'returns false if metadata.rb does not exist' do
      allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(false)
      expect(server.cookbook?).to eq false
    end
  end

  describe '#write_configs' do
    before do
      allow(Dir).to receive(:home).and_return('/root')
      allow(FileUtils).to receive(:mkdir_p).with '/root/.chef'
      allow(FileUtils).to receive(:mkdir_p).with '/root/.berkshelf'
    end

    it 'writes common conigs' do
      allow(server).to receive(:write_knife_rb)
      allow(server).to receive(:write_berks_config)

      expect(config).to receive(:write_configs)
      server.write_configs
    end

    it 'writes knife config' do
      allow(server).to receive(:write_berks_config)

      expect(FileUtils).to receive(:mkdir_p).with '/root/.chef'
      expect(File).to receive(:open).with('/root/.chef/knife.rb', 'w').and_yield(file)
      expect(file).to receive(:puts).with("node_name 'johndoe'")
      expect(file).to receive(:puts).with("client_key '/tmp/key.pem'")
      expect(file).to receive(:puts)
        .with("chef_server_url 'https://myserver.com/organizations/my_chef_org'")
      expect(file).to receive(:puts).with("chef_repo_path '/path/to/project'")
      expect(file).to receive(:puts).with('ssl_verify_mode :verify_none')

      server.write_configs
    end

    it 'writes berks config if disabling ssl_verify' do
      allow(server).to receive(:write_knife_rb)

      expect(FileUtils).to receive(:mkdir_p).with '/root/.berkshelf'
      expect(File).to receive(:open).with('/root/.berkshelf/config.json', 'w').and_yield(file)
      expect(file).to receive(:puts).with('{"ssl":{"verify":false}}')

      server.write_configs
    end

    it 'does not write berks config if ssl_verify enabled' do
      allow(server).to receive(:write_knife_rb)
      allow(config).to receive(:ssl_verify).and_return(true)
      expect(server).not_to receive(:write_berks_config)
      server.write_configs
    end
  end

  describe '#upload' do
    before do
      # Set normal defaults
      plugin_args.delete 'freeze'
      plugin_args.delete 'recursive'

      allow(server).to receive(:cookbook).and_return(cookbook)
      allow(Dir).to receive(:exist?)
        .with('/path/to/project/{roles,environments,data_bags}')
        .and_return(['/path/to/project/roles'])
      allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(true)
    end

    it 'retrieves cookbook and dependency cookbooks' do
      allow(server).to receive(:berksfile?).and_return(true)
      expect(berks_install_shellout).to receive(:run_command)
      server.upload
    end

    it 'uploads cookbooks to chef server' do
      allow(server).to receive(:berksfile?).and_return(true)
      expect(berks_upload_shellout).to receive(:run_command)
      server.upload
    end

    it 'uploads a cookbook to chef server' do
      plugin_args['recursive'] = false
      allow(server).to receive(:berksfile?).and_return(true)

      expect(Mixlib::ShellOut)
        .to receive(:new).with('berks upload test_cookbook -b /path/to/project/Berksfile')
        .and_return(berks_upload_shellout)
      expect(berks_upload_shellout).to receive(:run_command)
      server.upload
    end

    it 'does not freeze cookbooks uploaded to chef server' do
      plugin_args['freeze'] = false
      allow(server).to receive(:berksfile?).and_return(true)

      expect(Mixlib::ShellOut)
        .to receive(:new).with('berks upload -b /path/to/project/Berksfile --no-freeze')
        .and_return(berks_upload_shellout)
      expect(berks_upload_shellout).to receive(:run_command)
      server.upload
    end

    context 'if not a cookbook' do
      it 'uploads chef org data only when no cookbooks defined' do
        # allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(false)
        # allow(File).to receive(:exist?).with('/path/to/project/Berksfile').and_return(false)
        allow(server).to receive(:berksfile?).and_return(false)
        allow(server).to receive(:cookbook?).and_return(false)
        allow(server).to receive(:chef_data?).and_return(true)

        expect(server).not_to receive(:berks_install)
        expect(server).not_to receive(:berks_upload)
        expect(Dir).to receive(:chdir).with('/path/to/project')
        # expect(server).to receive(:`).with('knife upload . -c /root/.chef/knife.rb')
        server.upload
      end

      it 'uploads chef org data and cookbooks' do
        allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(false)
        allow(server).to receive(:berksfile?).and_return(true)
        allow(server).to receive(:cookbook?).and_return(false)
        allow(server).to receive(:chef_data?).and_return(true)

        expect(server).to receive(:berks_install)
        expect(server).to receive(:berks_upload)
        expect(Dir).to receive(:chdir).with('/path/to/project')
        expect(knife_upload_shellout).to receive(:run_command)
        server.upload
      end

      it 'does not upload chef org data if non exists' do
        allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(false)
        allow(server).to receive(:berksfile?).and_return(false)
        allow(server).to receive(:cookbook?).and_return(false)
        allow(server).to receive(:chef_data?).and_return(false)

        expect(knife_upload_shellout).not_to receive(:run_command)
        server.upload
      end
    end

    it 'does not upload chef org data from cookbooks' do
      allow(server).to receive(:berksfile?).and_return(true)
      allow(server).to receive(:cookbook?).and_return(true)
      allow(server).to receive(:chef_data?).and_return(true)

      expect(knife_upload_shellout).not_to receive(:run_command)
      server.upload
    end
  end
end
