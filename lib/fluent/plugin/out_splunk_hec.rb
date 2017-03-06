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
      msg = {time: time.to_i,
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
      @client = HTTPClient.new(default_header: header,
                               base_url: URI::HTTP.build(host: @host, port: @port))
    end

    def post(body)
      @client.post('/services/collector', body)
    end
  end
end
