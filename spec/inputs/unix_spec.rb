# encoding: utf-8
require_relative "../spec_helper"
require "logstash/devutils/rspec/shared_examples"
require 'logstash/plugin_mixins/ecs_compatibility_support/spec_helper'
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

  context "#server" do
    it_behaves_like "an interruptible input plugin" do
      let(:config) { super().merge "mode" => 'server' }
    end
  end

  context "#client", :ecs_compatibility_support do
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
        let(:allowed_lag) { 5 } # due Logstash 6.x in CI
      end
    end

    ecs_compatibility_matrix(:disabled, :v1, :v8) do |ecs_select|

      let(:config) { super().merge 'ecs_compatibility' => ecs_compatibility }

      let(:queue) { java.util.Vector.new }

      it 'generates events with host, path and message set' do
        subject.register
        Thread.new(subject, queue) { |subject, queue| subject.run(queue) }
        try(10) do
          expect( queue.size ).to_not eql 0
        end
        subject.do_stop # stop the plugin

        event = queue.first

        if ecs_select.active_mode == :disabled
          expect( event.get('host') ).to be_a String
          expect( event.get('path') ).to eql temp_path
        else
          expect( event.get('[host][name]') ).to be_a String
          expect( event.get('[file][path]') ).to eql temp_path
          expect( event.include?('path') ).to be false
        end

        expect( event.get('message') ).to eql 'foo'
      end

    end

  end

end
