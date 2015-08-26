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

end
