require "spec_helper"
require "drone"

describe Drone::Chef::Processor do
  include FakeFS::SpecHelpers
  # let(:server) { DroneChef::ChefServer.new build_data.to_json }
  # let(:config) { server.instance_variable_get(:@config) }
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
        "user" => "johndoe",
        "private_key" => "PEMDATAHERE",
        "ssl_verify" => false,
        "org" => "my_chef_org",
        "recursive" => false,
        "freeze" => false
      }
    }
  end

  let(:payload) do
    p = Drone::Plugin.new build_data.to_json
    p.parse
    p.result
  end

  let(:config) do
    Drone::Chef::Config.new payload
  end

  let(:processor) do
    Drone::Chef::Processor.new config
  end

  before do
    allow(Dir).to receive(:home).and_return "/root"
  end

  describe '#validate!' do
    it "passes when org is provided" do
      expect { processor.validate! }.not_to raise_error
    end

    it "fails when org is not provided" do
      build_data["vargs"]["org"] = nil
      expect { processor.validate! }
        .to raise_error("Please provide an organization")
    end
  end

  describe '#configure!' do
    before do
      allow(config).to receive(:configure!)
    end

    it "calls configure from Drone::Chef::Config" do
      expect(config).to receive(:configure!)

      processor.configure!
    end

    it "writes berks config file" do
      FakeFS do
        processor.configure!

        expect(File.read("/root/.berkshelf/config.json"))
          .to eq "{\"ssl\":{\"verify\":false}}\n"
      end
    end

    context "writes the knife config" do
      it "includes the username" do
        FakeFS do
          processor.configure!

          expect(File.read("/root/.chef/knife.rb"))
            .to include "node_name 'johndoe'"
        end
      end

      it "includes the key file path" do
        FakeFS do
          processor.configure!

          expect(File.read("/root/.chef/knife.rb"))
            .to include "client_key '/tmp/key.pem'"
        end
      end

      it "includes the server and org" do
        FakeFS do
          processor.configure!

          expect(File.read("/root/.chef/knife.rb"))
            .to include "chef_server_url 'https://myserver.com/organizations/my_chef_org'" # rubocop:disable LineLength
        end
      end

      it "includes the chef_repo_path" do
        FakeFS do
          processor.configure!

          expect(File.read("/root/.chef/knife.rb"))
            .to include "chef_repo_path '/path/to/project'"
        end
      end

      it "includes ssl_verify_mode" do
        FakeFS do
          processor.configure!

          expect(File.read("/root/.chef/knife.rb"))
            .to include "ssl_verify_mode :verify_none"
        end
      end
    end
  end

  # let(:file) { double('File') }
  # let(:cookbook) do
  #   instance_double('Chef::Cookbook::Metadata', name: 'test_cookbook', version: '1.2.3', from_file: nil)
  # end
  #
  # let(:berks_install_shellout) do
  #   double('berks install',
  #          run_command: nil, stdout: 'berks_install_stdout', stderr: 'berks_install_stderr', error?: false)
  # end
  # let(:berks_upload_shellout) do
  #   double('berks upload',
  #          run_command: nil, stdout: 'berks_upload_stdout', stderr: 'berks_upload_stderr', error?: false)
  # end
  # let(:knife_upload_shellout) do
  #   double('knife upload',
  #          run_command: nil, stdout: 'knife_upload_stdout', stderr: 'knife_upload_stderr', error?: false)
  # end
  #
  # before do
  #   $stdout = StringIO.new
  #   $stderr = StringIO.new
  #
  #   allow(Dir).to receive(:home).and_return '/root'
  #
  #   allow(File).to receive(:exist?).and_call_original
  #   allow(Dir).to receive(:exist?).and_call_original
  #
  #   # Shell command stubbing
  #   allow(Mixlib::ShellOut)
  #     .to receive(:new).with('berks install -b /path/to/project/Berksfile')
  #     .and_return(berks_install_shellout)
  #   allow(Mixlib::ShellOut)
  #     .to receive(:new).with('berks upload -b /path/to/project/Berksfile')
  #     .and_return(berks_upload_shellout)
  #   allow(Mixlib::ShellOut)
  #     .to receive(:new).with('knife upload . -c /root/.chef/knife.rb')
  #     .and_return(knife_upload_shellout)
  # end
  #
  # after do
  #   $stdout = STDOUT
  #   $stderr = STDERR
  # end
  #
  # describe '#recursive' do
  #   it 'returns the default if not provided' do
  #     build_data['vargs'].delete 'recursive'
  #     expect(server.recursive).to eq true
  #   end
  #
  #   it 'returns the user value' do
  #     expect(server.recursive).to eq false
  #   end
  # end
  #
  # describe '#freeze' do
  #   it 'returns the default if not provided' do
  #     build_data['vargs'].delete 'freeze'
  #     expect(server.freeze).to eq true
  #   end
  #
  #   it 'returns the user value' do
  #     expect(server.freeze).to eq false
  #   end
  # end
  #
  # describe '#berksfile?' do
  #   it 'returns true if Berksfile exists' do
  #     allow(File).to receive(:exist?).with('/path/to/project/Berksfile').and_return(true)
  #     allow(File).to receive(:exist?).with('/path/to/project/Berksfile.lock').and_return(false)
  #     expect(server.berksfile?).to eq true
  #   end
  #
  #   it 'returns true if Berksfile.lock exists' do
  #     allow(File).to receive(:exist?).with('/path/to/project/Berksfile').and_return(false)
  #     allow(File).to receive(:exist?).with('/path/to/project/Berksfile.lock').and_return(true)
  #     expect(server.berksfile?).to eq true
  #   end
  #
  #   it 'returns false if metadata.rb does not exist' do
  #     allow(File).to receive(:exist?).with('/path/to/project/Berksfile').and_return(false)
  #     allow(File).to receive(:exist?).with('/path/to/project/Berksfile.lock').and_return(false)
  #     expect(server.berksfile?).to eq false
  #   end
  # end
  #
  # describe '#cookbook?' do
  #   it 'returns true if metadata.rb exists' do
  #     allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(true)
  #     expect(server.cookbook?).to eq true
  #   end
  #
  #   it 'returns false if metadata.rb does not exist' do
  #     allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(false)
  #     expect(server.cookbook?).to eq false
  #   end
  # end
  #
  # describe '#write_configs' do
  #   before do
  #     allow(FileUtils).to receive(:mkdir_p).with '/root/.chef'
  #     allow(FileUtils).to receive(:mkdir_p).with '/root/.berkshelf'
  #     allow(config).to receive(:write_configs)
  #   end
  #
  #   it 'writes common conigs' do
  #     allow(server).to receive(:write_knife_rb)
  #     allow(server).to receive(:write_berks_config)
  #
  #     expect(config).to receive(:write_configs)
  #     server.write_configs
  #   end
  #
  #   it 'writes knife config' do
  #     allow(server).to receive(:write_berks_config)
  #
  #     expect(FileUtils).to receive(:mkdir_p).with '/root/.chef'
  #     expect(File).to receive(:open).with('/root/.chef/knife.rb', 'w').and_yield(file)
  #     expect(file).to receive(:puts).with("node_name 'johndoe'")
  #     expect(file).to receive(:puts).with("client_key '/tmp/key.pem'")
  #     expect(file).to receive(:puts)
  #       .with("chef_server_url 'https://myserver.com/organizations/my_chef_org'")
  #     expect(file).to receive(:puts).with("chef_repo_path '/path/to/project'")
  #     expect(file).to receive(:puts).with('ssl_verify_mode :verify_none')
  #
  #     server.write_configs
  #   end
  #
  #   it 'writes berks config if disabling ssl_verify' do
  #     allow(server).to receive(:write_knife_rb)
  #
  #     expect(FileUtils).to receive(:mkdir_p).with '/root/.berkshelf'
  #     expect(File).to receive(:open).with('/root/.berkshelf/config.json', 'w').and_yield(file)
  #     expect(file).to receive(:puts).with('{"ssl":{"verify":false}}')
  #
  #     server.write_configs
  #   end
  #
  #   it 'does not write berks config if ssl_verify enabled' do
  #     allow(server).to receive(:write_knife_rb)
  #     allow(config).to receive(:ssl_verify).and_return(true)
  #     expect(server).not_to receive(:write_berks_config)
  #     server.write_configs
  #   end
  # end
  #
  # describe '#upload' do
  #   before do
  #     # Set normal defaults
  #     build_data['vargs'].delete 'freeze'
  #     build_data['vargs'].delete 'recursive'
  #
  #     allow(Chef::Cookbook::Metadata).to receive(:new).and_return cookbook
  #     allow(File).to receive(:exist?).with(/Berksfile/).and_return true
  #
  #     allow(Dir).to receive(:exist?)
  #       .with('/path/to/project/{roles,environments,data_bags}')
  #       .and_return(['/path/to/project/roles'])
  #     allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(true)
  #   end
  #
  #   it 'retrieves cookbook and dependency cookbooks' do
  #     expect(berks_install_shellout).to receive(:run_command)
  #     server.upload
  #   end
  #
  #   it 'uploads cookbooks to chef server' do
  #     expect(berks_upload_shellout).to receive(:run_command)
  #     server.upload
  #   end
  #
  #   it 'uploads a cookbook to chef server' do
  #     build_data['vargs']['recursive'] = false
  #
  #     expect(Mixlib::ShellOut)
  #       .to receive(:new).with('berks upload test_cookbook -b /path/to/project/Berksfile')
  #       .and_return(berks_upload_shellout)
  #     expect(berks_upload_shellout).to receive(:run_command)
  #     server.upload
  #   end
  #
  #   it 'does not freeze cookbooks uploaded to chef server' do
  #     build_data['vargs']['freeze'] = false
  #
  #     expect(Mixlib::ShellOut)
  #       .to receive(:new).with('berks upload -b /path/to/project/Berksfile --no-freeze')
  #       .and_return(berks_upload_shellout)
  #     expect(berks_upload_shellout).to receive(:run_command)
  #     server.upload
  #   end
  #
  #   it 'does not upload chef org data from cookbooks' do
  #     allow(server).to receive(:cookbook?).and_return(true)
  #     allow(server).to receive(:chef_data?).and_return(true)
  #
  #     expect(knife_upload_shellout).not_to receive(:run_command)
  #     server.upload
  #   end
  #
  #   context 'if not a cookbook' do
  #     before do
  #       allow(server).to receive(:cookbook?).and_return(false)
  #     end
  #
  #     it 'uploads chef org data only when no cookbooks defined' do
  #       allow(server).to receive(:berksfile?).and_return(false)
  #       allow(server).to receive(:chef_data?).and_return(true)
  #
  #       expect(server).not_to receive(:berks_install)
  #       expect(server).not_to receive(:berks_upload)
  #       expect(Dir).to receive(:chdir).with('/path/to/project')
  #       expect(knife_upload_shellout).to receive(:run_command)
  #       server.upload
  #     end
  #
  #     it 'uploads chef org data and cookbooks' do
  #       allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(false)
  #       allow(server).to receive(:berksfile?).and_return(true)
  #       allow(server).to receive(:chef_data?).and_return(true)
  #
  #       expect(server).to receive(:berks_install)
  #       expect(server).to receive(:berks_upload)
  #       expect(Dir).to receive(:chdir).with('/path/to/project')
  #       expect(knife_upload_shellout).to receive(:run_command)
  #       server.upload
  #     end
  #
  #     it 'does not upload chef org data if non exists' do
  #       allow(File).to receive(:exist?).with('/path/to/project/metadata.rb').and_return(false)
  #       allow(server).to receive(:berksfile?).and_return(false)
  #       allow(server).to receive(:chef_data?).and_return(false)
  #
  #       expect(knife_upload_shellout).not_to receive(:run_command)
  #       server.upload
  #     end
  #   end
  #
  #   context 'logging' do
  #     it 'logs failure of retrieving cookbooks' do
  #       allow(berks_install_shellout).to receive(:error?).and_return true
  #       expect { server.upload }.to raise_error('ERROR: Failed to retrieve cookbooks')
  #     end
  #
  #     it 'logs failure of uploading cookbooks' do
  #       allow(berks_upload_shellout).to receive(:error?).and_return true
  #       expect { server.upload }.to raise_error('ERROR: Failed to upload cookbook')
  #     end
  #
  #     it 'logs failure of uploading chef org data' do
  #       allow(server).to receive(:cookbook?).and_return(false)
  #       allow(server).to receive(:chef_data?).and_return(true)
  #       allow(Dir).to receive(:chdir).with('/path/to/project')
  #       allow(knife_upload_shellout).to receive(:error?).and_return true
  #       expect { server.upload }.to raise_error('ERROR: knife upload failed')
  #     end
  #
  #     it 'does not give debug logs' do
  #       allow(config).to receive(:debug?).and_return true
  #       server.upload
  #       expect($stdout.string).to match(/DEBUG/)
  #     end
  #
  #     it 'does debug logs' do
  #       server.upload
  #       expect($stdout.string).not_to match(/DEBUG/)
  #     end
  #   end
  # end



end
