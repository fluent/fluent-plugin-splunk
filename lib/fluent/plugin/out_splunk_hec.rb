require 'fluent/output'
require 'httpclient'
require 'json'

# http://dev.splunk.com/view/event-collector/SP-CAAAE6P

module Fluent
  class SplunkHECOutput < ObjectBufferedOutput
    Fluent::Plugin.register_output('splunk_hec', self)

    config_param :host, :string, default: 'localhost'
    config_param :port, :integer, default: 8088
    config_param :token, :string, required: true
    config_param :default_source, :string, default: nil
    config_param :source_key, :string, default: nil
    config_param :time_key, :string, default: 'time'

    config_param :use_ack, :bool, default: false
    config_param :channel, :string, default: nil
    config_param :ack_interval, :integer, default: 1
    config_param :ack_retry_limit, :integer, default: 3

    ## TODO: more detailed option?
    ## For SSL
    config_param :ssl_verify_peer, :bool, default: false
    config_param :ca_file, :string, default: nil
    config_param :client_cert, :string, default: nil
    config_param :client_key, :string, default: nil
    config_param :client_key_pass, :string, default: nil

    def configure(conf)
      super
      raise ConfigError, "'channel' parameter is required when 'use_ack' is true" if @use_ack && !@channel
      raise ConfigError, "'ack_interval' parameter must be a non negative integer" if @use_ack && @ack_interval < 0
    end

    def start
      setup_client
      super
    end

    def shutdown
      super
    end

    def write_objects(_tag, chunk)
      return if chunk.empty?

      payload = ''
      chunk.msgpack_each do |time, record|
        time = record[@time_key] || time.to_i
        msg = {'time' => time,
               'sourcetype' => 'json',
               'event' => record}
        if record[@source_key]
          msg['source'] = record[@source_key]
        elsif @default_source
          msg['source'] = @default_source
        end
        payload << (msg.to_json + "\n")
      end

      post_payload(payload) unless payload.empty?
    end

    private
    def setup_client
      header = {'Content-type' => 'application/json',
                'Authorization' => "Splunk #{@token}"}
      header['X-Splunk-Request-Channel'] = @channel if @use_ack
      base_url = @ssl_verify_peer ? URI::HTTPS.build(host: @host, port: @port) : URI::HTTP.build(host: @host, port: @port)
      @client = HTTPClient.new(default_header: header,
                               base_url: base_url)
      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER if @ssl_verify_peer
      @client.ssl_config.add_trust_ca(@ca_file) if @ca_file
      @client.ssl_config.set_client_cert_file(@client_cert, @client_key, @client_key_pass) if @client_cert && @client_key
    end

    def post(path, body)
      @client.post(path, body)
    end

    def post_payload(payload)
      res = post('/services/collector', payload)
      log.debug "Splunk response: #{res.body}"
      if @use_ack
        res_json = JSON.parse(res.body)
        ack_id = res_json['ackId']
        check_ack(ack_id, @ack_retry_limit)
      end
    end

    def check_ack(ack_id, retries)
      raise "failed to index the data ack_id=#{ack_id}" if retries < 0

      ack_res = post('/services/collector/ack', {'acks' => [ack_id]}.to_json)
      ack_res_json = JSON.parse(ack_res.body)
      if ack_res_json['acks'] && ack_res_json['acks'][ack_id.to_s]
        return
      else
        sleep(@ack_interval)
        check_ack(ack_id, retries - 1)
      end
    end
  end
end
