require "spec_helper"

describe Drone::Chef::Processor do
  let(:valid_pkey) do
    OpenSSL::PKey::RSA.generate(2048).to_s
  end

  let(:options) do
    {
      server: "https://myserver.com",
      org: "my_chef_org",
      user: "johndoe",
      private_key: valid_pkey,
      ssl_verify: false,
      freeze: false,
      recursive: false,
      berks_files: ["Berksfile"]
    }
  end

  let(:stringio) do
    StringIO.new
  end

  let(:logger) do
    Logger.new stringio
  end

  let(:config) do
    c = Drone::Chef::Config.new options, logger
    allow(c).to receive(:home).and_return "/root"
    allow(c).to receive(:workspace_path).and_return "/path/to/project"
    c
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
    instance_double("Chef::Cookbook::Metadata", name: "test_cookbook",
                                                version: "1.2.3",
                                                from_file: nil)
  end

  describe "#configure!" do
    include FakeFS::SpecHelpers

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

    describe "#berksfile?" do
      it "returns true if Berksfile exists" do
        FakeFS do
          FileUtils.mkdir_p "/path/to/project"
          FileUtils.touch "/path/to/project/Berksfile"

          expect(processor.berksfile?).to eq true
        end
      end

      it "returns true if Berksfile.lock exists" do
        FakeFS do
          FileUtils.mkdir_p "/path/to/project"
          FileUtils.touch "/path/to/project/Berksfile.lock"

          expect(processor.berksfile?).to eq true
        end
      end

      it "returns false otherwise" do
        FakeFS do
          FileUtils.mkdir_p "/path/to/project"

          expect(processor.berksfile?).to eq false
        end
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

  describe "#upload!" do
    include FakeFS::SpecHelpers

    let(:cookbook) do
      instance_double("Chef::Cookbook::Metadata", name: "test_cookbook",
                                                  version: "1.2.3",
                                                  from_file: nil)
    end

    before do
      # Set normal defaults
      options[:freeze] = true
      options[:recursive] = true

      allow(Chef::Cookbook::Metadata).to receive(:new).and_return cookbook

      allow(Mixlib::ShellOut)
        .to receive(:new).with(/berks install/)
        .and_return(berks_install_shellout)
      allow(Mixlib::ShellOut)
        .to receive(:new).with(/berks upload/)
        .and_return(berks_upload_shellout)
    end

    after do
      FakeFS::FileSystem.clear
    end

    it "retrieves cookbook and dependency cookbooks" do
      FakeFS do
        FileUtils.mkdir_p "/path/to/project"
        FileUtils.touch "/path/to/project/Berksfile"

        expect(Mixlib::ShellOut)
          .to receive(:new).with("berks install -b /path/to/project/Berksfile")
        processor.upload!
      end
    end

    it "uploads cookbooks to chef server" do
      FakeFS do
        FileUtils.mkdir_p "/path/to/project"
        FileUtils.touch "/path/to/project/Berksfile"

        expect(Mixlib::ShellOut)
          .to receive(:new).with("berks upload -b /path/to/project/Berksfile")
          .and_return(berks_upload_shellout)

        processor.upload!
      end
    end

    it "uploads a cookbook to chef server" do
      options[:recursive] = false

      FakeFS do
        FileUtils.mkdir_p "/path/to/project"
        FileUtils.touch "/path/to/project/Berksfile"
        FileUtils.touch "/path/to/project/metadata.rb"

        expect(Mixlib::ShellOut)
          .to receive(:new)
          .with("berks upload test_cookbook -b /path/to/project/Berksfile")
          .and_return(berks_upload_shellout)
        expect(berks_upload_shellout).to receive(:run_command)

        processor.upload!
      end
    end

    it "does not freeze cookbooks uploaded to chef server" do
      options[:freeze] = false

      FakeFS do
        FileUtils.mkdir_p "/path/to/project"
        FileUtils.touch "/path/to/project/Berksfile"

        expect(Mixlib::ShellOut)
          .to receive(:new)
          .with("berks upload -b /path/to/project/Berksfile --no-freeze")
          .and_return(berks_upload_shellout)
        expect(berks_upload_shellout).to receive(:run_command)

        processor.upload!
      end
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
        FakeFS do
          FileUtils.mkdir_p "/path/to/project/roles"

          expect(processor).not_to receive(:berks_install)
          expect(processor).not_to receive(:berks_upload)
          expect(Dir).to receive(:chdir).with("/path/to/project")
          expect(Mixlib::ShellOut)
            .to receive(:new).with("knife upload . -c /root/.chef/knife.rb")
            .and_return(knife_upload_shellout)

          processor.upload!
        end
      end

      it "uploads chef org data and cookbooks" do
        FakeFS do
          FileUtils.mkdir_p "/path/to/project/roles"
          FileUtils.touch "/path/to/project/Berksfile"

          expect(processor).to receive(:berks_install)
          expect(processor).to receive(:berks_upload)

          expect(Dir).to receive(:chdir).with("/path/to/project")
          expect(Mixlib::ShellOut)
            .to receive(:new).with("knife upload . -c /root/.chef/knife.rb")
            .and_return(knife_upload_shellout)

          processor.upload!
        end
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
    end

    after do
      FakeFS::FileSystem.clear
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
      FakeFS do
        FileUtils.mkdir_p "/path/to/project/roles"

        allow(knife_upload_shellout).to receive(:error?).and_return true

        expect { processor.upload! }
          .to raise_error("ERROR: knife upload failed")
      end
    end

    it "does produce debug logs" do
      allow(config).to receive(:debug?).and_return true
      allow(processor).to receive(:berksfile?).and_return true

      processor.upload!

      expect(stringio.string).to match(/DEBUG/)
    end

    it "does not produce debug logs" do
      processor.upload!

      expect(stringio.string).not_to match(/DEBUG/)
    end
  end
end
