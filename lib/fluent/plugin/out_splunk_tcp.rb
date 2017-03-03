require 'fluent/output'
require 'socket'
require 'json'

# http://dev.splunk.com/view/event-collector/SP-CAAAE6P

module Fluent
  class SplunkTCPOutput < BufferedOutput
    Fluent::Plugin.register_output('splunk_tcp', self)

    config_param :host, :string, default: 'localhost'
    config_param :port, :integer, required: true
    config_param :source, :string, default: 'fluentd'

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
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |_tag, time, record|
        msg = {time: time.to_i,
               event: record.to_json}

        sock = TCPSocket.open(@host, @port)
        sock.write(msg.to_json)
        sock.close
      end
    end
  end
end
