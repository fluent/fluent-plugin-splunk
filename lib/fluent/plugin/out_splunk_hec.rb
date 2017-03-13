require 'fluent/output'
require 'httpclient'
require 'json'

# http://dev.splunk.com/view/event-collector/SP-CAAAE6P

module Fluent
  class SplunkHECOutput < BufferedOutput
    Fluent::Plugin.register_output('splunk_hec', self)

    config_param :host, :string, default: 'localhost'
    config_param :port, :integer, default: 8088
    config_param :token, :string, default: nil
    config_param :source, :string, default: 'fluentd'
    config_param :sourcetype, :string, default: 'json'
    config_param :use_ack, :bool, default: false
    config_param :channel, :string, default: nil

    ## TODO: more detailed option?
    ## For SSL
    config_param :ssl_verify_peer, :bool, default: true
    config_param :ca_file, :string, default: nil
    config_param :client_cert, :string, default: nil
    config_param :client_key, :string, default: nil
    config_param :client_key_pass, :string, default: nil

    def configure(conf)
      super
      raise ConfigError, "'token' parameter is required" unless @token
      raise ConfigError, "'channel' parameter is required when 'use_ack' is true" if @use_ack && !@channel
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
      res = post('/services/collector', chunk.read)
      log.debug "Splunk response: #{res.body}"
      if @use_ack
        res_json = JSON.parse(res.body)
        ack_id = res_json['ackId']
        ack_res = post('/services/collector/ack', {'acks' => [ack_id]}.to_json)
        log.debug "Splunk response: #{ack_res.body}"
        ack_res_json = JSON.parse(ack_res.body)
        unless ack_res_json['acks'][ack_id.to_s]
          sleep(3)
          ack_res = post('/services/collector/ack', {'acks' => [ack_id]}.to_json)
          log.debug "Splunk response: #{ack_res.body}"
          ack_res_json = JSON.parse(ack_res.body)
        end
        raise "failed to index the data ack_id=#{ack_id}" unless ack_res_json['acks'][ack_id.to_s]
      end
    end

    private
    def setup_client
      header = {'Content-type' => 'application/json',
                'Authorization' => "Splunk #{@token}"}
      header['X-Splunk-Request-Channel'] = @channel if @use_ack
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

    def post(path, body)
      @client.post(path, body)
    end
  end
end
