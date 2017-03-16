require 'fluent/output'
require 'socket'
require 'openssl'
require 'json'

# http://dev.splunk.com/view/event-collector/SP-CAAAE6P

module Fluent
  class SplunkTCPOutput < ObjectBufferedOutput
    Fluent::Plugin.register_output('splunk_tcp', self)

    config_param :host, :string, default: 'localhost'
    config_param :port, :integer, required: true
    config_param :source, :string, default: 'fluentd'
    config_param :time_key, :string, default: 'time'

    ## TODO: more detailed option?
    ## For SSL
    config_param :ssl_verify_peer, :bool, default: true
    config_param :ca_file, :string, default: nil
    config_param :client_cert, :string, default: nil
    config_param :client_key, :string, default: nil
    config_param :client_key_pass, :string, default: nil

    def configure(conf)
      super
    end

    def start
      super
    end

    def shutdown
      super
    end

    def write_objects(_tag, chunk)
      return if chunk.empty?

      payload = ''
      chunk.msgpack_each do |time, record|
        if record[@time_key]
          payload << (record.to_json + "\n")
        else
          payload << ({@time_key => time.to_i}.merge(record).to_json + "\n")
        end
      end

      unless payload.empty?
        sock = create_socket
        sock.write(payload)
        sock.close
      end
    end

    private
    def create_socket
      if @ssl_verify_peer
        create_ssl_socket
      else
        create_tcp_socket
      end
    end

    def create_ssl_socket
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
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
