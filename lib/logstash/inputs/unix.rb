# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "logstash/util/socket_peer"

require 'logstash/plugin_mixins/ecs_compatibility_support'

# Read events over a UNIX socket.
#
# Like `stdin` and `file` inputs, each event is assumed to be one line of text.
#
# Can either accept connections from clients or connect to a server,
# depending on `mode`.
class LogStash::Inputs::Unix < LogStash::Inputs::Base

  include LogStash::PluginMixins::ECSCompatibilitySupport(:disabled, :v1, :v8 => :v1)

  config_name "unix"

  default :codec, "line"

  # When mode is `server`, the path to listen on.
  # When mode is `client`, the path to connect to.
  config :path, :validate => :string, :required => true

  # Remove socket file in case of EADDRINUSE failure
  config :force_unlink, :validate => :boolean, :default => false

  # The 'read' timeout in seconds. If a particular connection is idle for
  # more than this timeout period, we will assume it is dead and close it.
  #
  # If you never want to timeout, use -1.
  config :data_timeout, :validate => :number, :default => -1

  # Mode to operate in. `server` listens for client connections,
  # `client` connects to a server.
  config :mode, :validate => ["server", "client"], :default => "server"

  # Amount of time in seconds to wait if the socket file is not present, before retrying.
  # Only positive values are allowed.
  #
  # This setting is only used if `mode` is `client`.
  config :socket_not_present_retry_interval_seconds, :validate => :number, :required => true, :default => 5

  def initialize(*params)
    super

    @host_name_field = ecs_select[disabled: 'host', v1: '[host][name]']
    @file_path_field = ecs_select[disabled: 'path', v1: '[file][path]']
  end # def initialize

  public
  def register
    require "socket"

    if server?
      @logger.info("Starting unix input listener", :address => @path, :force_unlink => @force_unlink)
      begin
        @server_socket = UNIXServer.new(@path)
      rescue Errno::EADDRINUSE, IOError
        if @force_unlink
          File.unlink(@path)
          begin
            @server_socket = UNIXServer.new(@path)
            return
          rescue Errno::EADDRINUSE, IOError
            @logger.error("Could not start UNIX server: address in use", :path => @path)
            raise
          end
        end
        @logger.error("Could not start UNIX server: address in use", :path => @path)
        raise
      end
    else # client
      if socket_not_present_retry_interval_seconds < 0
        @logger.warn("Value #{socket_not_present_retry_interval_seconds} for socket_not_present_retry_interval_seconds is not valid, using default value of 5 instead")
        @socket_not_present_retry_interval_seconds = 5
      end
    end
  end # def register

  private
  def handle_socket(socket, output_queue)
    begin
      hostname = Socket.gethostname
      while !stop?
        data = socket.read_nonblock(16384, exception: false)

        if data == :wait_readable
          if @data_timeout == -1 || IO.select([socket], nil, nil, @data_timeout)
            retry # socket read operation
          else
            # socket not ready after @data_timeout seconds
            @logger.info("Closing connection after read timeout", :path => @path)
            return
          end
        end

        @codec.decode(data) do |event|
          decorate(event)
          event.set(@host_name_field, hostname) unless event.include?(@host_name_field)
          event.set(@file_path_field, @path) unless event.include?(@file_path_field)
          output_queue << event
        end
      end
    rescue => e
      if @logger.debug?
        @logger.debug("Closing connection", :path => @path, :exception => e, :backtrace => e.backtrace)
      else
        @logger.info("Closing connection", :path => @path, :exception => e)
      end
    end
  ensure
    begin
      socket.close
    rescue IOError
      #pass
    end
  end

  private
  def server?
    @mode == "server"
  end # def server?

  public
  def run(output_queue)
    if server?
      @client_threads = []
      while !stop?
        # Start a new thread for each connection.
        @client_threads << Thread.start(@server_socket.accept) do |s|
          @logger.debug("Accepted connection", :server => @path)
          handle_socket(s, output_queue)
        end
      end
    else
      while !stop?
        if File.socket?(@path)
          @client_socket = UNIXSocket.new(@path)
          @client_socket.instance_eval { class << self; include ::LogStash::Util::SocketPeer end }
          @logger.debug("Opened connection", :client => @path)
          handle_socket(@client_socket, output_queue)
        else
          @logger.warn("Socket not present, wait for #{socket_not_present_retry_interval_seconds} seconds for socket to appear", :client => @path)
          sleep socket_not_present_retry_interval_seconds
        end
      end
    end
  rescue IOError
    # if stop is called during @server_socket.accept
    # the thread running `run` will raise an IOError
    # We catch IOError here and do nothing, just let the method terminate
  end # def run

  public
  def stop
    if server?
      File.unlink(@path)
      @server_socket.close unless @server_socket.nil?
    else
      @client_socket.close unless @client_socket.nil?
    end
  rescue IOError
    # if socket with @mode == client was closed by the client, an other call to @client_socket.close
    # will raise an IOError. We catch IOError here and do nothing, just let logstash terminate
    @logger.warn("Could not close socket while Logstash is shutting down. Socket already closed by the other party?", :path => @path)
  end # def stop
end # class LogStash::Inputs::Unix
