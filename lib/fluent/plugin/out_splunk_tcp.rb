require 'fluent/output'
require 'socket'
require 'openssl'
require 'json'

# http://dev.splunk.com/view/event-collector/SP-CAAAE6P

module Fluent
  class SplunkTCPOutput < BufferedOutput
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

    def format(tag, time, record)
      # TODO: should be done in #write and use ObjectBufferedOutput?
      if record[@time_key]
        record.to_json + "\n"
      else
        {@time_key => time.to_i}.merge(record).to_json + "\n"
      end
    end

    def write(chunk)
      sock = create_socket
      sock.write(chunk.read)
      sock.close
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
