require 'fluent/plugin/output'
require 'fluent/time'
require 'fluent/config/error'
require 'socket'
require 'openssl'
require 'json'

# http://dev.splunk.com/view/event-collector/SP-CAAAE6P

module Fluent::Plugin
  class SplunkTCPOutput < Output
    Fluent::Plugin.register_output('splunk_tcp', self)

    helpers :compat_parameters

    config_param :host, :string
    config_param :port, :integer

    config_param :format, :string, default: 'raw'

    # for raw format
    config_param :event_key, :string, default: nil

    # for json, kv format
    config_param :use_fluentd_time, :bool, default: true
    config_param :time_key, :string, default: 'time'
    config_param :time_format, :string, default: 'unixtime'
    config_param :localtime, :bool, default: false

    config_param :line_breaker, :string, default: "\n"

    ## For SSL
    config_param :use_ssl, :bool, default: false
    config_param :ssl_verify, :bool, default: true
    config_param :ca_file, :string, default: nil
    config_param :client_cert, :string, default: nil
    config_param :client_key, :string, default: nil
    config_param :client_key_pass, :string, default: nil

    def implement?(feature)
      if feature == :custom_format
        return false
      end
      super
    end

    def configure(conf)
      compat_parameters_convert(conf, :buffer)

      super

      case @time_format
      when 'unixtime'
        @time_formatter = lambda {|time| time.to_i }
      else
        @timef = Fluent::TimeFormatter.new(@time_format, @localtime)
        @time_formatter = lambda {|time| @timef.format(time) }
      end

      case @format
      when 'json'
        if @use_fluentd_time
          @formatter = lambda {|time, record| Yajl.dump(insert_time_to_front(time, record)) }
        else
          @formatter = lambda {|_time, record| Yajl.dump(record) }
        end
      when 'kv'
        if @use_fluentd_time
          @formatter = lambda {|time, record| format_kv(insert_time_to_front(time, record)) }
        else
          @formatter = lambda {|_time, record| format_kv(record) }
        end
      when 'raw'
        unless @event_key
          raise Fluent::ConfigError, "'event_key' option is required for format 'raw'"
        end
        @formatter = lambda {|_time, record| record[@event_key] || '' }
      else
        raise Fluent::ConfigError, "invalid 'format' option: #{@format}"
      end
    end

    def multi_workers_ready?
      true
    end

    def start
      super
    end

    def shutdown
      super
    end

    def write(chunk)
      return if chunk.empty?

      payload = ''
      chunk.msgpack_each do |time, record|
        event = @formatter.call(time, record)
        unless event.empty?
          payload << event
          payload << @line_breaker
        end
      end

      unless payload.empty?
        sock = create_socket
        sock.write(payload)
        sock.close
      end
    end

    private
    def insert_time_to_front(time, record)
      record.delete(@time_key)
      {@time_key => @time_formatter.call(time)}.merge(record)
    end

    def format_kv(record)
      record.map{|k,v|
        case v
        when nil
          "#{k}="
        when Integer
          "#{k}=#{v}"
        when Float
          "#{k}=#{v}"
        else
          "#{k}=\"#{v.to_s.gsub('"', '\"')}\""
        end
      }.join(' ')
    end

    def create_socket
      @use_ssl ? create_ssl_socket : create_tcp_socket
    end

    def create_ssl_socket
      ctx = OpenSSL::SSL::SSLContext.new
      verify_mode = (@ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE)
      ctx.verify_mode = verify_mode
      ctx.cert = OpenSSL::X509::Certificate.new(File.read(@client_cert)) if @client_cert
      ctx.key = OpenSSL::PKey::RSA.new(File.read(@client_key), @client_key_pass) if @client_key

      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      cert_store.add_file(@ca_file) if @ca_file

      ctx.cert_store = cert_store

      tcpsock = create_tcp_socket
      sock = OpenSSL::SSL::SSLSocket.new(tcpsock, ctx)
      sock.sync_close = true
      sock.connect
      sock
    end

    def create_tcp_socket
      TCPSocket.open(@host, @port)
    end
  end
end
