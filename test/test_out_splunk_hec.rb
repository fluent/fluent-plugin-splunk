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

  ## query(port, 'source="SourceName"')
  def get_events(port, search_query)
    query(port, {'search' => 'search ' + search_query})
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
    assert_equal nil, d.instance.default_index
    assert_equal nil, d.instance.index_key
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

  DEFAULT_CONFIG_NO_ACK = %[
    host 127.0.0.1
    token 00000000-0000-0000-0000-000000000000
    use_ack false
  ]

  ## need channel option too
  DEFAULT_CONFIG_ACK = %[
    host 127.0.0.1
    token 00000000-0000-0000-0000-000000000001
    use_ack true
  ]

  def self.merge_config(config1, config2)
    [config1, config2].join("\n")
  end

  def merge_config(config1, config2)
    self.class.merge_config(config1, config2)
  end

  ## I just wanna run same test code for HTTP and HTTPS...
  [{sub_test_case_name: 'HTTP', query_port: 8089, config: %[
                                                            port 8088
                                                            ssl_verify_peer false
                                                          ]},
   {sub_test_case_name: 'HTTPS', query_port: 8289, config: %[
                                                            port 8288
                                                            ssl_verify_peer true
                                                            ca_file #{File.expand_path('../cert/cacert.pem', __FILE__)}
                                                            client_cert #{File.expand_path('../cert/client.pem', __FILE__)}
                                                            client_key #{File.expand_path('../cert/client.key', __FILE__)}
                                                            ]}
  ].each do |test_config|
    test_config[:default_config_no_ack] = merge_config(test_config[:config], DEFAULT_CONFIG_NO_ACK)
    test_config[:default_config_ack] = merge_config(test_config[:config], DEFAULT_CONFIG_ACK)

    sub_test_case test_config[:sub_test_case_name] do
      teardown do
        query(test_config[:query_port], {'search' => "search source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\" | delete"})
        query(test_config[:query_port], {'search' => "search source=\"#{DEFAULT_SOURCE_FOR_ACK}\" | delete"})
        query(test_config[:query_port], {'search' => 'search source="DefaultSourceTest" | delete'})
        query(test_config[:query_port], {'search' => 'search source="SourceKeyTest" | delete'})
        query(test_config[:query_port], {'search' => 'search index="default_index_test" | delete'})
        query(test_config[:query_port], {'search' => 'search index="index_key_test" | delete'})
      end

      if SPLUNK_VERSION >= to_version('6.3.0')
        test 'use_ack = false' do
          d = create_driver(test_config[:default_config_no_ack])
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'source="http:FluentTestNoAck"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'default_source' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_source DefaultSourceTest
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'source="DefaultSourceTest"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'source_key is found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            source_key key_for_source
          ])
          d = create_driver(config)
          event = {'key_for_source' => 'SourceKeyTest', 'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'source="SourceKeyTest"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'source_key is not found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            source_key key_for_source
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'both default_source and source_key when source_key is found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_source DefaultSourceTest
            source_key key_for_source
          ])
          d = create_driver(config)
          event = {'key_for_source' => 'SourceKeyTest', 'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'source="SourceKeyTest"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'both default_source and source_key when source_key is not found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_source DefaultSourceTest
            source_key key_for_source
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'source="DefaultSourceTest"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'default_index' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_index default_index_test
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'index="default_index_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'index_key is found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            index_key key_for_index
          ])
          d = create_driver(config)
          event = {'key_for_index' => 'index_key_test', 'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'index="index_key_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'index_key is not found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            index_key key_for_index
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'both default_index and index_key when index_key is found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_index default_index_test
            index_key key_for_source
          ])
          d = create_driver(config)
          event = {'key_for_source' => 'index_key_test', 'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'index="index_key_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'both default_index and index_key when index_key is not found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_index default_index_test
            index_key key_for_index
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          sleep(3)
          result = get_events(test_config[:query_port], 'index="default_index_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end
      end

      if SPLUNK_VERSION >= to_version('6.4.0')
        test 'use_ack = true' do
          config = merge_config(test_config[:default_config_ack], %[
            channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_ACK}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end
      end
    end
  end
end
