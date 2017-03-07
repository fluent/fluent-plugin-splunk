require 'fluent/output'
require 'httpclient'
require 'json'

# http://dev.splunk.com/view/event-collector/SP-CAAAE6P

module Fluent
  class SplunkHECOutput < BufferedOutput
    Fluent::Plugin.register_output('splunk_hec', self)

    config_param :host, :string, default: 'localhost'
    config_param :port, :integer, default: 8088
    config_param :token, :string, required: true
    config_param :source, :string, default: 'fluentd'
    config_param :sourcetype, :string, default: 'json'

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
      setup_client
      super
    end

    def shutdown
      super
    end

    def format(tag, time, record)
      # TODO: should be done in #write and use ObjectBufferedOutput?
      time = record['time'] || time.to_i
      msg = {time: time,
             sourcetype: @sourcetype,
             event: record.to_json}
      msg.to_json + "\n"
    end

    def write(chunk)
      post(chunk.read)
    end

    private
    def setup_client
      header = {'Content-type' => 'application/json',
                'Authorization' => "Splunk #{@token}"}
      base_url = if @ssl_verify_peer
                   URI::HTTPS.build(host: @host, port: @port)
                 else
                   URI::HTTP.build(host: @host, port: @port)
                 end
      @client = HTTPClient.new(default_header: header,
                               base_url: base_url)
      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER if @ssl_verify_peer
      @client.ssl_config.add_trust_ca(@ca_file) if @ca_file
      @client.ssl_config.set_client_cert_file(@client_cert, @client_key, @client_key_pass) if @client_cert && @client_key
    end

    def post(body)
      @client.post('/services/collector', body)
    end
  end
end
