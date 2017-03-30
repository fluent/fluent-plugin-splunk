require 'helper'
require 'test/unit'
require 'fluent/test'
require 'fluent/plugin/out_splunk_tcp'

require 'net/https'
require 'uri'
require 'json'
require 'securerandom'

class SplunkTCPOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  def teardown
  end

  CONFIG = %[
    port 8089
    event_key event
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::SplunkTCPOutput){
      # Fluentd v0.12 BufferedOutputTestDriver calls this method.
      # BufferedOutput#format_stream calls format method, but ForwardOutput#format is not defined.
      # Because ObjectBufferedOutput#emit calls es.to_msgpack_stream directly.
      def format_stream(tag, es)
        es.to_msgpack_stream
      end
    }.configure(conf)
  end

  ## query(port, 'source="SourceName"')
  test 'configure' do
    d = create_driver
    assert_equal 'localhost', d.instance.host
    assert_equal 8089, d.instance.port
    assert_equal 'raw', d.instance.format
    assert_equal 'event', d.instance.event_key
    assert_equal true, d.instance.use_fluentd_time
    assert_equal 'time', d.instance.time_key
    assert_equal 'unixtime', d.instance.time_format
    assert_equal false, d.instance.localtime
    assert_equal "\n", d.instance.line_breaker
    assert_equal false, d.instance.use_ssl
    assert_equal false, d.instance.ssl_verify
    assert_equal nil, d.instance.ca_file
    assert_equal nil, d.instance.client_cert
    assert_equal nil, d.instance.client_key
    assert_equal nil, d.instance.client_key_pass
  end

  def self.merge_config(config1, config2)
    [config1, config2].join("\n")
  end

  def merge_config(config1, config2)
    self.class.merge_config(config1, config2)
  end


  PORT_MAP = {
    fluentd_json_unixtime: 0,
    fluentd_json_unixtime2: 1,
    fluentd_json_strftime: 2,
    fluentd_kv_unixtime: 3,
    fluentd_kv_unixtime2: 4,
    fluentd_kv_strftime: 5,
  }

  def port(base, type = :fluentd_json_unixtime)
    diff = PORT_MAP[type]
    raise "invalid port type" unless diff
    base + diff
  end

  def with_timezone(tz)
    oldtz, ENV['TZ'] = ENV['TZ'], tz
    yield
  ensure
    ENV['TZ'] = oldtz
  end

  ## It is assumed string elements doesn't contain ' ' and '='
  def parse_kv(str)
    str.split(' ').map{|attr|
      k, v = attr.split('=')
      if v.start_with?('"') && v.end_with?('"')
        v = v.gsub(/^"/, '').gsub(/"$/, '').gsub('\"', '"')
      elsif v =~ /^\d+$/
        v = v.to_i
      elsif v =~ /^\d+\.\d+$/
        v = v.to_f
      else
        raise "invalid value as kv: #{v}"
      end
      [k, v]
    }.to_h
  end

  ## I just wanna run same test code for HTTP and HTTPS...
  [{sub_test_case_name: 'TCP', query_port: 8089, server_port_base: 12300, config: %[
                                                                                    host 127.0.0.1
                                                                                    use_ssl false
                                                                                  ]},
   {sub_test_case_name: 'SSL', query_port: 8289, server_port_base: 12500, config: %[
                                                                                    host 127.0.0.1
                                                                                    use_ssl true
                                                                                    ca_file #{File.expand_path('../cert/cacert.pem', __FILE__)}
                                                                                    client_cert #{File.expand_path('../cert/client.pem', __FILE__)}
                                                                                    client_key #{File.expand_path('../cert/client.key', __FILE__)}
                                                                                  ]}
  ].each do |test_config|
    sub_test_case test_config[:sub_test_case_name] do
      teardown do
        PORT_MAP.keys.each do |port|
          query(test_config[:query_port], {'search' => "search source=\"tcp:#{port(test_config[:server_port_base], port)}\" | delete"})
        end
      end

      sub_test_case 'raw format' do
        test 'single insert' do
          config = merge_config(test_config[:config], %[
            port #{port(test_config[:server_port_base])}
            format raw
            event_key event
          ])
          d = create_driver(config)
          time = Time.now.to_i - 100
          event = {'time' => time, 'test' => SecureRandom.hex}
          d.emit({'event' => event.to_json}, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port(test_config[:server_port_base])}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'batched insert' do
          config = merge_config(test_config[:config], %[
            port #{port(test_config[:server_port_base])}
            format raw
            event_key event
          ])
          d = create_driver(config)
          time0 = Time.now.to_i - 100
          event0 = {'time' => time0, 'test' => SecureRandom.hex}
          time1 = Time.now.to_i - 200
          event1 = {'time' => time1, 'test' => SecureRandom.hex}
          d.emit({'event' => event0.to_json}, time0)
          d.emit({'event' => event1.to_json}, time1)
          d.run
          events = get_events(test_config[:query_port], "source=\"tcp:#{port(test_config[:server_port_base])}\"", 2)
          assert_equal(time0, events[0]['result']['_time'].to_i)
          assert_equal(event0, JSON.parse(events[0]['result']['_raw']))
          assert_equal(time1, events[1]['result']['_time'].to_i)
          assert_equal(event1, JSON.parse(events[1]['result']['_raw']))
        end
      end

      sub_test_case 'json format' do
        test 'default' do
          port = port(test_config[:server_port_base], :fluentd_json_unixtime)
          config = merge_config(test_config[:config], %[
            port #{port}
            format json
          ])
          d = create_driver(config)
          time = Time.now.to_i - 100
          event = {'test' => SecureRandom.hex}
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal({'time' => time}.merge(event), JSON.parse(result['result']['_raw']))
        end

        test 'time_key=time2' do
          port = port(test_config[:server_port_base], :fluentd_json_unixtime2)
          config = merge_config(test_config[:config], %[
            port #{port}
            format json
            time_key time2
          ])
          d = create_driver(config)
          time = Time.now.to_i - 100
          event = {'test' => SecureRandom.hex}
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal({'time2' => time}.merge(event), JSON.parse(result['result']['_raw']))
        end

        test 'time_key=strftime' do
          port = port(test_config[:server_port_base], :fluentd_json_strftime)
          config = merge_config(test_config[:config], %[
            port #{port}
            format json
            time_format %Y-%m-%dT%H:%M:%S%z
          ])
          d = create_driver(config)
          time = Time.now.to_i - 100
          event = {'test' => SecureRandom.hex}
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal({'time' => Time.at(time).utc.strftime('%Y-%m-%dT%H:%M:%S%z')}.merge(event), JSON.parse(result['result']['_raw']))
        end

        test 'time_key=strftime, localtime=true' do
          port = port(test_config[:server_port_base], :fluentd_json_strftime)
          config = merge_config(test_config[:config], %[
            port #{port}
            format json
            time_format %Y-%m-%dT%H:%M:%S%z
            localtime true
          ])
          time = Time.now.to_i - 100
          with_timezone("UTC-04") do
            d = create_driver(config)
            event = {'test' => SecureRandom.hex}
            d.emit(event, time)
            d.run
            result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
            assert_equal(time, result['result']['_time'].to_i)
            assert_equal({'time' => Time.at(time).strftime('%Y-%m-%dT%H:%M:%S%z')}.merge(event), JSON.parse(result['result']['_raw']))
            assert_equal(time, DateTime.strptime(JSON.parse(result['result']['_raw'])['time'], '%Y-%m-%dT%H:%M:%S%z').to_time.to_i)
          end
        end

        test 'use_fluentd_time=false' do
          port = port(test_config[:server_port_base], :fluentd_json_unixtime)
          config = merge_config(test_config[:config], %[
            port #{port}
            format json
            use_fluentd_time false
          ])
          d = create_driver(config)
          time0 = Time.now.to_i - 100
          time1 = time0 - 100
          event = {'time' => time0, 'test' => SecureRandom.hex}
          d.emit(event, time1)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
          assert_equal(time0, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end
      end

      sub_test_case 'kv format' do
        test 'default' do
          port = port(test_config[:server_port_base], :fluentd_kv_unixtime)
          config = merge_config(test_config[:config], %[
            port #{port}
            format kv
          ])
          d = create_driver(config)
          time = Time.now.to_i - 100
          event = {'test' => SecureRandom.hex, 'escape' => 'a"b'}
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal({'time' => time}.merge(event), parse_kv(result['result']['_raw']))
        end

        test 'time_key=time2' do
          port = port(test_config[:server_port_base], :fluentd_kv_unixtime2)
          config = merge_config(test_config[:config], %[
            port #{port}
            format kv
            time_key time2
          ])
          d = create_driver(config)
          time = Time.now.to_i - 100
          event = {'test' => SecureRandom.hex}
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal({'time2' => time}.merge(event), parse_kv(result['result']['_raw']))
        end

        test 'time_key=strftime' do
          port = port(test_config[:server_port_base], :fluentd_kv_strftime)
          config = merge_config(test_config[:config], %[
            port #{port}
            format kv
            time_format %Y-%m-%dT%H:%M:%S%z
          ])
          d = create_driver(config)
          time = Time.now.to_i - 100
          event = {'test' => SecureRandom.hex}
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal({'time' => Time.at(time).utc.strftime('%Y-%m-%dT%H:%M:%S%z')}.merge(event), parse_kv(result['result']['_raw']))
        end

        test 'time_key=strftime, localtime=true' do
          port = port(test_config[:server_port_base], :fluentd_kv_strftime)
          config = merge_config(test_config[:config], %[
            port #{port}
            format kv
            time_format %Y-%m-%dT%H:%M:%S%z
            localtime true
          ])
          time = Time.now.to_i - 100
          with_timezone("UTC-04") do
            d = create_driver(config)
            event = {'test' => SecureRandom.hex}
            d.emit(event, time)
            d.run
            result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
            assert_equal(time, result['result']['_time'].to_i)
            assert_equal({'time' => Time.at(time).strftime('%Y-%m-%dT%H:%M:%S%z')}.merge(event), parse_kv(result['result']['_raw']))
            assert_equal(time, DateTime.strptime(parse_kv(result['result']['_raw'])['time'], '%Y-%m-%dT%H:%M:%S%z').to_time.to_i)
          end
        end

        test 'use_fluentd_time=false' do
          port = port(test_config[:server_port_base], :fluentd_kv_unixtime)
          config = merge_config(test_config[:config], %[
            port #{port}
            format kv
            use_fluentd_time false
          ])
          d = create_driver(config)
          time0 = Time.now.to_i - 100
          time1 = time0 - 100
          event = {'time' => time0, 'test' => SecureRandom.hex}
          d.emit(event, time1)
          d.run
          result = get_events(test_config[:query_port], "source=\"tcp:#{port}\"")[0]
          assert_equal(time0, result['result']['_time'].to_i)
          assert_equal(event, parse_kv(result['result']['_raw']))
        end
      end
    end
  end

  sub_test_case 'SSL misc' do
    teardown do
      PORT_MAP.keys.each do |port|
        query(8289, {'search' => "search source=\"tcp:#{port(12500, port)}\" | delete"})
      end
    end

    sub_test_case 'with invalid certificate' do
      ## realize by changing ca_file
      test 'ssl_verify=true' do
        config = %[
          host 127.0.0.1
          port #{port(12500)}
          format raw
          event_key event
          use_ssl true
          ssl_verify true
          ca_file #{File.expand_path('../cert/badcacert.pem', __FILE__)}
          client_cert #{File.expand_path('../cert/client.pem', __FILE__)}
          client_key #{File.expand_path('../cert/client.key', __FILE__)}
        ]
        d = create_driver(config)
        time = Time.now.to_i - 100
        event = {'time' => time, 'test' => SecureRandom.hex}
        d.emit({'event' => event.to_json}, time)
        assert_raise OpenSSL::SSL::SSLError, "SSL_connect returned=1 errno=0 state=error: certificate verify failed" do
          d.run
        end
      end

      test 'ssl_verify=false' do
        config = %[
          host 127.0.0.1
          port #{port(12500)}
          format raw
          event_key event
          use_ssl true
          ssl_verify false
          ca_file #{File.expand_path('../cert/badcacert.pem', __FILE__)}
          client_cert #{File.expand_path('../cert/client.pem', __FILE__)}
          client_key #{File.expand_path('../cert/client.key', __FILE__)}
        ]
        d = create_driver(config)
        time = Time.now.to_i - 100
        event = {'time' => time, 'test' => SecureRandom.hex}
        d.emit({'event' => event.to_json}, time)
        d.run
        result = get_events(8289, "source=\"tcp:#{port(12500)}\"")[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end
    end
  end
end
