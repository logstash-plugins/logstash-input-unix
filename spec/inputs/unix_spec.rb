# encoding: utf-8
require_relative "../spec_helper"
require "stud/temporary"
require "tempfile"

describe LogStash::Inputs::Unix do

  let(:tempfile)   { Tempfile.new("/tmp/foo") }

  it "should register without errors" do
    plugin = LogStash::Plugin.lookup("input", "unix").new({ "path" => tempfile.path, "force_unlink" => true })
    expect { plugin.register }.to_not raise_error
  end

  describe "when interrupting the plugin" do

    context "#server" do
      it_behaves_like "an interruptible input plugin" do
        let(:config) { { "path" => tempfile.path, "force_unlink" => true } }
      end
    end

    context "#client" do
      let(:tempfile)    { "/tmp/sock#{rand(65532)}" }
      let(:config)      { { "path" => tempfile, "mode" => "client" } }
      let(:unix_socket) { UnixSocketHelper.new.new_socket(tempfile) }
      let(:run_forever) { true }

      before(:each) do
        unix_socket.loop(run_forever)
      end

      after(:each) do
        unix_socket.close
      end

      context "when the unix socket has data to be read" do
        it_behaves_like "an interruptible input plugin" do
          let(:run_forever) { true }
        end
      end

      context "when the unix socket has no data to be read" do
        it_behaves_like "an interruptible input plugin" do
          let(:run_forever) { false }
        end
      end
    end

  end
end
