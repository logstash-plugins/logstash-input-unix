# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/inputs/unix'

class UnixSocketHelper

  attr_reader :path

  def initialize(line = 'hi!')
    @socket = nil
    @line = line
  end

  def new_socket(path)
    @path = path
    File.unlink if File.exists?(path) && File.socket?(path)
    @socket = UNIXServer.new(path)
    self
  end

  def loop(forever=false)
    @thread = Thread.new do
      begin
        s = @socket.accept
        s.puts @line while forever
      rescue Errno::EPIPE, Errno::ECONNRESET => e
        warn e.inspect if $VERBOSE
      end
    end
    self
  end

  def close
    @socket.close
    File.unlink(path)
  end
end
