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
    config_param :time_key, :string, default: 'time'

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
      sock = TCPSocket.open(@host, @port)
      sock.write(chunk)
      sock.close
    end
  end
end
