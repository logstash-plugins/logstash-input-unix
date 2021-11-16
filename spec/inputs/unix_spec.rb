# encoding: utf-8
require_relative "../spec_helper"
require "logstash/devutils/rspec/shared_examples"
require "stud/temporary"
require "tempfile"

describe LogStash::Inputs::Unix do

  let(:config) { { 'path' => tempfile.path, 'socket_not_present_retry_interval_seconds' => 1, 'force_unlink' => true } }
  let(:tempfile) { Tempfile.new("unix-input-test") }

  subject(:input) { described_class.new(config) }

  it "should register without errors" do
    expect { subject.register }.to_not raise_error
  end

  describe "when mode is client" do

    let(:config) { super().merge("mode" => 'client', "socket_not_present_retry_interval_seconds" => -1) }

    context "if socket_not_present_retry_interval_seconds is out of bounds" do
      it "should fallback to default value" do
        subject.register
        expect( subject.socket_not_present_retry_interval_seconds ).to eql 5
      end
    end
  end

  describe "when interrupting the plugin" do

    context "#server" do
      it_behaves_like "an interruptible input plugin" do
        let(:config) { super() }
      end
    end

    context "#client" do
      let(:temp_path)    { "/tmp/sock#{rand(65532)}" }
      let(:config)      { super().merge "path" => temp_path, "mode" => "client" }
      let(:unix_socket) { UnixSocketHelper.new('foo').new_socket(temp_path) }
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

      let(:queue) { Array.new }

      it 'generates events with host, path and message set' do
        subject.register
        plugin_thread = Thread.new(subject, queue) { |subject, queue| subject.run(queue) }
        sleep 0.5
        expect(plugin_thread).to be_alive
        subject.do_stop # stop the plugin

        expect( queue ).to_not be_empty
        event = queue.first

        expect( event.get('host') ).to be_a String
        expect( event.get('path') ).to eql temp_path

        expect( event.get('message') ).to eql 'foo'
      end
    end

  end
end
