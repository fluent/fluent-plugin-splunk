require 'fluent/output'
require 'httpclient'
require 'json'
require 'securerandom'

# http://dev.splunk.com/view/event-collector/SP-CAAAE6P

module Fluent
  class SplunkHECOutput < ObjectBufferedOutput
    Fluent::Plugin.register_output('splunk_hec', self)

    config_param :host, :string
    config_param :port, :integer
    config_param :token, :string

    # for metadata
    config_param :default_host, :string, default: nil
    config_param :host_key, :string, default: nil
    config_param :remove_host_key, :bool, default: false
    config_param :default_source, :string, default: nil
    config_param :source_key, :string, default: nil
    config_param :remove_source_key, :bool, default: false
    config_param :default_index, :string, default: nil
    config_param :index_key, :string, default: nil
    config_param :remove_index_key, :bool, default: false
    config_param :sourcetype, :string, default: nil, deprecated: "Use default_sourcetype instead"
    config_param :default_sourcetype, :string, default: nil
    config_param :sourcetype_key, :string, default: nil
    config_param :remove_sourcetype_key, :bool, default: false
    config_param :use_fluentd_time, :bool, default: true    

    # for Indexer acknowledgement
    config_param :use_ack, :bool, default: false
    config_param :channel, :string, default: nil
    config_param :auto_generate_channel, :bool, default: false
    config_param :ack_interval, :integer, default: 1
    config_param :ack_retry_limit, :integer, default: 3

    # for raw events
    config_param :raw, :bool, default: false
    config_param :event_key, :string, default: nil

    # misc
    config_param :line_breaker, :string, default: "\n"

    ## For SSL
    config_param :use_ssl, :bool, default: false
    config_param :ssl_verify, :bool, default: true
    config_param :ca_file, :string, default: nil
    config_param :client_cert, :string, default: nil
    config_param :client_key, :string, default: nil
    config_param :client_key_pass, :string, default: nil

    def configure(conf)
      super

      if @channel && @auto_generate_channel 
        log.warn "Both channel and auto_generate_channel are set.. ignoring channel param and auto generating channel instead"
      end

      @channel = SecureRandom.uuid if @auto_generate_channel

      raise ConfigError, "'channel' parameter is required when 'use_ack' is true" if @use_ack && !@channel
      raise ConfigError, "'ack_interval' parameter must be a non negative integer" if @use_ack && @ack_interval < 0
      raise ConfigError, "'event_key' parameter is required when 'raw' is true" if @raw && !@event_key
      raise ConfigError, "'channel' parameter is required when 'raw' is true" if @raw && !@channel
      
      @default_sourcetype = @sourcetype if @sourcetype && !@default_sourcetype

      # build hash for query string
      if @raw
        @query = {}
        @query['host'] = @default_host if @default_host
        @query['source'] = @default_source if @default_source
        @query['index'] = @default_index if @default_index
        @query['sourcetype'] = @default_sourcetype if @default_sourcetype
      end
    end

    def multi_workers_ready?
      true
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
        payload << (@raw ? format_event_raw(record) : format_event(time, record))
      end
      post_payload(payload) unless payload.empty?
    end

    private
    def setup_client
      header = {'Content-type' => 'application/json',
                'Authorization' => "Splunk #{@token}"}
      header['X-Splunk-Request-Channel'] = @channel if @channel
      base_url = @use_ssl ? URI::HTTPS.build(host: @host, port: @port) : URI::HTTP.build(host: @host, port: @port)
      @client = HTTPClient.new(default_header: header,
                               base_url: base_url)
      if @use_ssl
        verify_mode = (@ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE)
        @client.ssl_config.verify_mode = verify_mode
        @client.ssl_config.add_trust_ca(@ca_file) if @ca_file
        @client.ssl_config.set_client_cert_file(@client_cert, @client_key, @client_key_pass) if @client_cert && @client_key
      end
    end

    def format_event(time, record)
      if @event_key
        msg = {'event' => (record[@event_key] || '')}
      else
        msg = {'event' => record}
      end

      if @use_fluentd_time
        msg['time'] = time.respond_to?('to_f') ? time.to_f : time
      end

      # metadata
      if record[@sourcetype_key]
        msg['sourcetype'] = @remove_sourcetype_key ? record.delete(@sourcetype_key) : record[@sourcetype_key]
      elsif @default_sourcetype
        msg['sourcetype'] = @default_sourcetype
      end

      if record[@host_key]
        msg['host'] = @remove_host_key ? record.delete(@host_key) : record[@host_key]
      elsif @default_host
        msg['host'] = @default_host
      end

      if record[@source_key]
        msg['source'] =  @remove_source_key ? record.delete(@source_key) : record[@source_key]
      elsif @default_source
        msg['source'] = @default_source
      end

      if record[@index_key]
        msg['index'] = @remove_index_key ? record.delete(@index_key) : record[@index_key]
      elsif @default_index
        msg['index'] = @default_index
      end

      res = Yajl.dump(msg)
      res << @line_breaker
      res
    end

    def format_event_raw(record)
      if record[@event_key] and not record[@event_key].strip.empty?
        record[@event_key] + @line_breaker
      else
        log.debug "Discarding empty line"
        ''
      end
    end

    def post(path, body, query = {})
      @client.post(path, body: body, query: query)
    end

    def post_payload(payload)
      res = nil
      if @raw
        res = post('/services/collector/raw', payload, @query)
      else
        res = post('/services/collector', payload)
      end
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
