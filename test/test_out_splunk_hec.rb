require 'helper'
require 'test/unit'
require 'fluent/test'
require 'fluent/plugin/out_splunk_hec'

require 'net/https'
require 'uri'
require 'json'
require 'securerandom'

class SplunkHECOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  def teardown
  end

  CONFIG = %[
    token 00000000-0000-0000-0000-000000000000
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::SplunkHECOutput){
      # Fluentd v0.12 BufferedOutputTestDriver calls this method.
      # BufferedOutput#format_stream calls format method, but ForwardOutput#format is not defined.
      # Because ObjectBufferedOutput#emit calls es.to_msgpack_stream directly.
      def format_stream(tag, es)
        es.to_msgpack_stream
      end
    }.configure(conf)
  end

  def get_events(port, source)
    query(port, {'search' => "search source=\"#{source}\""})
  end

  def cert_dir(file)
    File.expand_path(File.join('../cert', file), __FILE__)
  end

  def query(port, q)
    uri = URI.parse("https://127.0.0.1:#{port}/services/search/jobs/export")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Post.new(uri.path)
    req.basic_auth('admin', 'changeme')
    req.set_form_data(q.merge({'output_mode' => 'json', 'time_format' => '%s'}))
    http.request(req).body.split("\n").map{|line| JSON.parse(line)}.delete_if{|json| json['lastrow']}
  end

  test 'configure' do
    d = create_driver
    assert_equal 'localhost', d.instance.host
    assert_equal 8088, d.instance.port
    assert_equal '00000000-0000-0000-0000-000000000000', d.instance.token
    assert_equal nil, d.instance.default_source
    assert_equal nil, d.instance.source_key
    assert_equal 'time', d.instance.time_key
    assert_equal false, d.instance.use_ack
    assert_equal nil, d.instance.channel
    assert_equal 1, d.instance.ack_interval
    assert_equal 3, d.instance.ack_retry_limit
    assert_equal false, d.instance.ssl_verify_peer
    assert_equal nil, d.instance.ca_file
    assert_equal nil, d.instance.client_cert
    assert_equal nil, d.instance.client_key
    assert_equal nil, d.instance.client_key_pass
  end

  ## These are specified in the target Splunk's config
  DEFAULT_SOURCE_FOR_NO_ACK = "http:FluentTestNoAck"
  DEFAULT_SOURCE_FOR_ACK = "http:FluentTestAck"

  sub_test_case 'HTTP' do
    teardown do
      query(8089, {'search' => "search source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\" | delete"})
      query(8089, {'search' => "search source=\"#{DEFAULT_SOURCE_FOR_ACK}\" | delete"})
      query(8089, {'search' => 'search source="DefaultSourceTest" | delete'})
      query(8089, {'search' => 'search source="SourceKeyTest" | delete'})
    end


    if SPLUNK_VERSION >= to_version('6.3.0')
      test 'use_ack = false' do
        config = %[
          host 127.0.0.1
          port 8088
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer false
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8089, 'http:FluentTestNoAck')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'default_source' do
        config = %[
          host 127.0.0.1
          port 8088
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer false
          default_source DefaultSourceTest
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8089, 'DefaultSourceTest')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'source_key is found' do
        config = %[
          host 127.0.0.1
          port 8088
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer false
          source_key key_for_source
        ]
        d = create_driver(config)
        event = {'key_for_source' => 'SourceKeyTest', 'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8089, 'SourceKeyTest')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'source_key is not found' do
        config = %[
          host 127.0.0.1
          port 8088
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer false
          source_key key_for_source
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8089, DEFAULT_SOURCE_FOR_NO_ACK)[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'both default_source and source_key when source_key is found' do
        config = %[
          host 127.0.0.1
          port 8088
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer false
          default_source DefaultSourceTest
          source_key key_for_source
        ]
        d = create_driver(config)
        event = {'key_for_source' => 'SourceKeyTest', 'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8089, 'SourceKeyTest')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'both default_source and source_key when source_key is not found' do
        config = %[
          host 127.0.0.1
          port 8088
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer false
          default_source DefaultSourceTest
          source_key key_for_source
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8089, 'DefaultSourceTest')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end
    end

    if SPLUNK_VERSION >= to_version('6.4.0')
      test 'use_ack = true' do
        config = %[
          host 127.0.0.1
          port 8088
          token 00000000-0000-0000-0000-000000000001
          channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
          use_ack true
          ssl_verify_peer false
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        result = get_events(8089, 'http:FluentTestAck')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end
    end
  end

  sub_test_case 'HTTPS' do
    teardown do
      query(8289, {'search' => "search source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\" | delete"})
      query(8289, {'search' => "search source=\"#{DEFAULT_SOURCE_FOR_ACK}\" | delete"})
      query(8289, {'search' => 'search source="DefaultSourceTest" | delete'})
      query(8289, {'search' => 'search source="SourceKeyTest" | delete'})
    end

    if SPLUNK_VERSION >= to_version('6.3.0')
      test 'use_ack = false' do
        config = %[
          host 127.0.0.1
          port 8288
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer true
          ca_file #{cert_dir('cacert.pem')}
          client_cert #{cert_dir('client.pem')}
          client_key #{cert_dir('client.key')}
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8289, 'http:FluentTestNoAck')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'default_source' do
        config = %[
          host 127.0.0.1
          port 8288
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer true
          ca_file #{cert_dir('cacert.pem')}
          client_cert #{cert_dir('client.pem')}
          client_key #{cert_dir('client.key')}
          default_source DefaultSourceTest
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8289, 'DefaultSourceTest')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'source_key is found' do
        config = %[
          host 127.0.0.1
          port 8288
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer true
          ca_file #{cert_dir('cacert.pem')}
          client_cert #{cert_dir('client.pem')}
          client_key #{cert_dir('client.key')}
          source_key key_for_source
        ]
        d = create_driver(config)
        event = {'key_for_source' => 'SourceKeyTest', 'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8289, 'SourceKeyTest')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'source_key is not found' do
        config = %[
          host 127.0.0.1
          port 8288
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer true
          ca_file #{cert_dir('cacert.pem')}
          client_cert #{cert_dir('client.pem')}
          client_key #{cert_dir('client.key')}
          source_key key_for_source
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8289, DEFAULT_SOURCE_FOR_NO_ACK)[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'both default_source and source_key when source_key is found' do
        config = %[
          host 127.0.0.1
          port 8288
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer true
          ca_file #{cert_dir('cacert.pem')}
          client_cert #{cert_dir('client.pem')}
          client_key #{cert_dir('client.key')}
          default_source DefaultSourceTest
          source_key key_for_source
        ]
        d = create_driver(config)
        event = {'key_for_source' => 'SourceKeyTest', 'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8289, 'SourceKeyTest')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end

      test 'both default_source and source_key when source_key is not found' do
        config = %[
          host 127.0.0.1
          port 8288
          token 00000000-0000-0000-0000-000000000000
          use_ack false
          ssl_verify_peer true
          ca_file #{cert_dir('cacert.pem')}
          client_cert #{cert_dir('client.pem')}
          client_key #{cert_dir('client.key')}
          default_source DefaultSourceTest
          source_key key_for_source
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        sleep(3)
        result = get_events(8289, 'DefaultSourceTest')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end
    end

    if SPLUNK_VERSION >= to_version('6.4.0')
      test 'use_ack = true' do
        config = %[
          host 127.0.0.1
          port 8288
          token 00000000-0000-0000-0000-000000000001
          channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
          use_ack true
          ssl_verify_peer true
          ca_file #{cert_dir('cacert.pem')}
          client_cert #{cert_dir('client.pem')}
          client_key #{cert_dir('client.key')}
        ]
        d = create_driver(config)
        event = {'test' => SecureRandom.hex}
        time = Time.now.to_i
        d.emit(event, time)
        d.run
        result = get_events(8289, 'http:FluentTestAck')[0]
        assert_equal(time, result['result']['_time'].to_i)
        assert_equal(event, JSON.parse(result['result']['_raw']))
      end
    end
  end
end
