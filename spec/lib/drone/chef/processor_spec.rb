require "spec_helper"
require "drone"

describe Drone::Chef::Processor do
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

  let(:berks_install_shellout) do
    double("berks install", run_command: nil, stdout: "berks_install_stdout",
                            stderr: "berks_install_stderr", error?: false)
  end

  let(:berks_upload_shellout) do
    double("berks upload", run_command: nil, stdout: "berks_upload_stdout",
                           stderr: "berks_upload_stderr", error?: false)
  end

  let(:knife_upload_shellout) do
    double("knife upload", run_command: nil, stdout: "knife_upload_stdout",
                           stderr: "knife_upload_stderr", error?: false)
  end

  let(:cookbook) do
    instance_double('Chef::Cookbook::Metadata', name: 'test_cookbook', version: '1.2.3', from_file: nil)
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

  describe '#upload!' do
    let(:cookbook) do
      instance_double("Chef::Cookbook::Metadata", name: "test_cookbook",
                                                  version: "1.2.3",
                                                  from_file: nil)
    end

    before do
      # Set normal defaults
      build_data["vargs"].delete "freeze"
      build_data["vargs"].delete "recursive"

      allow(Chef::Cookbook::Metadata).to receive(:new).and_return cookbook
      allow(File).to receive(:exist?).with(/Berksfile/).and_return true

      allow(Mixlib::ShellOut)
        .to receive(:new).with(/berks install/)
        .and_return(berks_install_shellout)
      allow(Mixlib::ShellOut)
        .to receive(:new).with(/berks upload/)
        .and_return(berks_upload_shellout)

      allow(Dir).to receive(:exist?)
        .with("/path/to/project/{roles,environments,data_bags}")
        .and_return(["/path/to/project/roles"])
      allow(File).to receive(:exist?).with("/path/to/project/metadata.rb")
        .and_return(true)
    end

    it "retrieves cookbook and dependency cookbooks" do
      expect(Mixlib::ShellOut)
        .to receive(:new).with("berks install -b /path/to/project/Berksfile")
      processor.upload!
    end

    it "uploads cookbooks to chef server" do
      expect(Mixlib::ShellOut)
        .to receive(:new).with("berks upload -b /path/to/project/Berksfile")
        .and_return(berks_upload_shellout)

      processor.upload!
    end

    it "uploads a cookbook to chef server" do
      build_data["vargs"]["recursive"] = false

      expect(Mixlib::ShellOut)
        .to receive(:new)
        .with("berks upload test_cookbook -b /path/to/project/Berksfile")
        .and_return(berks_upload_shellout)
      expect(berks_upload_shellout).to receive(:run_command)
      processor.upload!
    end

    it "does not freeze cookbooks uploaded to chef server" do
      build_data["vargs"]["freeze"] = false

      expect(Mixlib::ShellOut)
        .to receive(:new)
        .with("berks upload -b /path/to/project/Berksfile --no-freeze")
        .and_return(berks_upload_shellout)
      expect(berks_upload_shellout).to receive(:run_command)
      processor.upload!
    end

    it "does not upload chef org data from cookbooks" do
      allow(processor).to receive(:cookbook?).and_return(true)
      allow(processor).to receive(:chef_data?).and_return(true)

      expect(Mixlib::ShellOut)
        .not_to receive(:new).with(/knife upload/)
      processor.upload!
    end

    context "if not a cookbook" do
      before do
        allow(processor).to receive(:cookbook?).and_return(false)
      end

      it "uploads chef org data only when no cookbooks defined" do
        allow(processor).to receive(:berksfile?).and_return(false)
        allow(processor).to receive(:chef_data?).and_return(true)

        expect(processor).not_to receive(:berks_install)
        expect(processor).not_to receive(:berks_upload)
        expect(Dir).to receive(:chdir).with("/path/to/project")
        expect(Mixlib::ShellOut)
          .to receive(:new).with("knife upload . -c /root/.chef/knife.rb")
          .and_return(knife_upload_shellout)

        processor.upload!
      end

      it "uploads chef org data and cookbooks" do
        allow(File).to receive(:exist?).with("/path/to/project/metadata.rb")
          .and_return(false)
        allow(processor).to receive(:berksfile?).and_return(true)
        allow(processor).to receive(:chef_data?).and_return(true)

        expect(processor).to receive(:berks_install)
        expect(processor).to receive(:berks_upload)
        expect(Dir).to receive(:chdir).with("/path/to/project")
        expect(Mixlib::ShellOut)
          .to receive(:new).with("knife upload . -c /root/.chef/knife.rb")
          .and_return(knife_upload_shellout)

        processor.upload!
      end

      it "does not upload chef org data if non exists" do
        allow(File).to receive(:exist?).with("/path/to/project/metadata.rb")
          .and_return(false)
        allow(processor).to receive(:berksfile?).and_return(false)
        allow(processor).to receive(:chef_data?).and_return(false)

        expect(Mixlib::ShellOut)
          .not_to receive(:new).with(/knife upload/)

        processor.upload!
      end
    end
  end

  context "logging" do
    before do
      allow(Mixlib::ShellOut)
        .to receive(:new).with(/berks install/)
        .and_return(berks_install_shellout)
      allow(Mixlib::ShellOut)
        .to receive(:new).with(/berks upload/)
        .and_return(berks_upload_shellout)
      allow(Mixlib::ShellOut)
        .to receive(:new).with(/knife upload/)
        .and_return(knife_upload_shellout)
      allow(processor).to receive(:cookbook).and_return cookbook

      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    after do
      $stdout = STDOUT
      $stderr = STDERR
    end

    it "logs failure of retrieving cookbooks" do
      allow(processor).to receive(:berksfile?).and_return true
      allow(berks_install_shellout).to receive(:error?).and_return true

      expect { processor.upload! }
        .to raise_error("ERROR: Failed to retrieve cookbooks")
    end

    it "logs failure of uploading cookbooks" do
      allow(processor).to receive(:berksfile?).and_return true
      allow(berks_upload_shellout).to receive(:error?).and_return true

      expect { processor.upload! }
        .to raise_error("ERROR: Failed to upload cookbook")
    end

    it "logs failure of uploading chef org data" do
      allow(processor).to receive(:chef_data?).and_return(true)
      allow(Dir).to receive(:chdir).with("/path/to/project")
      allow(knife_upload_shellout).to receive(:error?).and_return true

      expect { processor.upload! }.to raise_error("ERROR: knife upload failed")
    end

    it "does not give debug logs" do
      allow(config).to receive(:debug?).and_return true
      allow(processor).to receive(:berksfile?).and_return true

      processor.upload!

      expect($stdout.string).to match(/DEBUG/)
    end

    it "does debug logs" do
      processor.upload!

      expect($stdout.string).not_to match(/DEBUG/)
    end
  end
end
