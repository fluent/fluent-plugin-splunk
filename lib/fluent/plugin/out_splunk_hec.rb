require 'fluent/output'
require 'net/http'
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
      http = Net::HTTP.new(host, port)
      req = Net::HTTP::Post.new('/services/collector')
      req['Content-Type'] = 'application/json'
      req['Authorization'] = "Splunk #{@token}"

      req.body = chunk.read
      http.request(req)
    end
  end
end
