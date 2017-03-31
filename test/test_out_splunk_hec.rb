require 'helper'
require 'test/unit'
require 'fluent/test'
require 'fluent/plugin/out_splunk_hec'

require 'net/https'
require 'uri'
require 'json'
require 'securerandom'

class SplunkHECOutputTest < Test::Unit::TestCase
  self.test_order = :random

  def setup
    Fluent::Test.setup
  end

  def teardown
  end

  CONFIG = %[
    host 127.0.0.1
    port 8088
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

  test 'configure' do
    d = create_driver
    assert_equal '127.0.0.1', d.instance.host
    assert_equal 8088, d.instance.port
    assert_equal '00000000-0000-0000-0000-000000000000', d.instance.token
    assert_equal nil, d.instance.default_host
    assert_equal nil, d.instance.host_key
    assert_equal nil, d.instance.default_source
    assert_equal nil, d.instance.source_key
    assert_equal nil, d.instance.default_index
    assert_equal nil, d.instance.index_key
    assert_equal nil, d.instance.sourcetype
    assert_equal false, d.instance.use_ack
    assert_equal nil, d.instance.channel
    assert_equal 1, d.instance.ack_interval
    assert_equal 3, d.instance.ack_retry_limit
    assert_equal false, d.instance.use_ssl
    assert_equal true, d.instance.ssl_verify
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
                                                            use_ssl false
                                                          ]},
   {sub_test_case_name: 'HTTPS', query_port: 8289, config: %[
                                                             port 8288
                                                             use_ssl true
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
        query(test_config[:query_port], {'search' => 'search host="default_host_test" | delete'})
        query(test_config[:query_port], {'search' => 'search host="host_key_test" | delete'})
        query(test_config[:query_port], {'search' => 'search source="DefaultSourceTest" | delete'})
        query(test_config[:query_port], {'search' => 'search source="SourceKeyTest" | delete'})
        query(test_config[:query_port], {'search' => 'search index="default_index_test" | delete'})
        query(test_config[:query_port], {'search' => 'search index="index_key_test" | delete'})
      end

      if SPLUNK_VERSION >= to_version('6.3.0')
        test 'use_ack = false' do
          d = create_driver(test_config[:default_config_no_ack])
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'batched insert' do
          d = create_driver(test_config[:default_config_no_ack])
          event0 = {'test' => SecureRandom.hex}
          time0 = Time.now.to_i - 100
          event1 = {'test' => SecureRandom.hex}
          time1 = Time.now.to_i - 200
          d.emit(event0, time0)
          d.emit(event1, time1)
          d.run
          events = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"", 2)
          assert_equal(time0, events[0]['result']['_time'].to_i)
          assert_equal(event0, JSON.parse(events[0]['result']['_raw']))
          assert_equal(time1, events[1]['result']['_time'].to_i)
          assert_equal(event1, JSON.parse(events[1]['result']['_raw']))
        end

        test 'default_host' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_host default_host_test
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], 'host="default_host_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'host_key is found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            host_key key_for_host
          ])
          d = create_driver(config)
          event = {'key_for_host' => 'host_key_test', 'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], 'host="host_key_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'host_key is not found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            host_key key_for_host
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'both default_host and host_key when host_key is found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_host default_host_test
            host_key key_for_host
          ])
          d = create_driver(config)
          event = {'key_for_host' => 'host_key_test', 'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], 'host="host_key_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'both default_host and host_key when host_key is not found' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_host default_host_test
            host_key key_for_host
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], 'host="default_host_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'default_source' do
          config = merge_config(test_config[:default_config_no_ack], %[
            default_source DefaultSourceTest
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], 'index="default_index_test"')[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end

        test 'source_type = sourcetype_test' do
          config = merge_config(test_config[:default_config_no_ack], %[
            sourcetype sourcetype_test
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal('sourcetype_test', result['result']['_sourcetype'])
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
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_ACK}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end
      end

      if SPLUNK_VERSION >= to_version('6.4.0')
        sub_test_case 'raw' do
          test 'with metadata' do
            config = merge_config(test_config[:default_config_no_ack], %[
              raw true
              channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
              event_key splunk_event
              sourcetype fluentd_json_unixtime
              default_host default_host_test
              default_source DefaultSourceTest
              default_index default_index_test
            ])

            d = create_driver(config)
            time = Time.now.to_i - 100
            event = {'time' => time, 'msg' => 'msg'}
            record = {'splunk_event' => event.to_json}
            d.emit(record, time)
            d.run
            result = get_events(test_config[:query_port], 'source="DefaultSourceTest"')[0]
            assert_equal(time, result['result']['_time'].to_i)
            assert_equal('fluentd_json_unixtime', result['result']['sourcetype'])
            assert_equal('default_host_test', result['result']['host'])
            assert_equal('DefaultSourceTest', result['result']['source'])
            assert_equal('default_index_test', result['result']['index'])
            assert_equal(event, JSON.parse(result['result']['_raw']))
          end

          test 'batched data with metadata' do
            config = merge_config(test_config[:default_config_no_ack], %[
              raw true
              channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
              event_key splunk_event
              sourcetype fluentd_json_unixtime
              default_host default_host_test
              default_source DefaultSourceTest
              default_index default_index_test
            ])

            d = create_driver(config)
            time0 = Time.now.to_i - 100
            event0 = {'time' => time0, 'msg' => 'msg0'}
            record0 = {'splunk_event' => event0.to_json}
            time1 = Time.now.to_i - 200
            event1 = {'time' => time1, 'msg' => 'msg1'}
            record1 = {'splunk_event' => event1.to_json}
            d.emit(record0, time0)
            d.emit(record1, time1)
            d.run
            events = get_events(test_config[:query_port], 'source="DefaultSourceTest"', 2)
            assert_equal(time0, events[0]['result']['_time'].to_i)
            assert_equal('fluentd_json_unixtime', events[0]['result']['sourcetype'])
            assert_equal('default_host_test', events[0]['result']['host'])
            assert_equal('DefaultSourceTest', events[0]['result']['source'])
            assert_equal('default_index_test', events[0]['result']['index'])
            assert_equal(event0, JSON.parse(events[0]['result']['_raw']))
            assert_equal(time1, events[1]['result']['_time'].to_i)
            assert_equal('fluentd_json_unixtime', events[1]['result']['sourcetype'])
            assert_equal('default_host_test', events[1]['result']['host'])
            assert_equal('DefaultSourceTest', events[1]['result']['source'])
            assert_equal('default_index_test', events[1]['result']['index'])
            assert_equal(event1, JSON.parse(events[1]['result']['_raw']))
          end

          test 'without metadata' do
            config = merge_config(test_config[:default_config_no_ack], %[
              raw true
              channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
              event_key splunk_event
            ])

            d = create_driver(config)
            time = Time.now.to_i - 100
            event = {'time' => time, 'msg' => 'msg'}
            record = {'splunk_event' => event.to_json}
            d.emit(record, time)
            d.run
            result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"")[0]
            assert_equal(event, JSON.parse(result['result']['_raw']))
          end
        end

        sub_test_case 'raw = false with event_key' do
          if SPLUNK_VERSION >= to_version('6.5.0')
            test 'with metadata' do
              config = merge_config(test_config[:default_config_no_ack], %[
                raw false
                channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
                event_key splunk_event
                sourcetype fluentd_json_unixtime
                default_host default_host_test
                default_source DefaultSourceTest
                default_index default_index_test
              ])

              d = create_driver(config)
              time = Time.now.to_i - 100
              event = {'time' => time, 'msg' => 'msg'}
              record = {'splunk_event' => event.to_json}
              d.emit(record, time)
              d.run
              result = get_events(test_config[:query_port], 'source="DefaultSourceTest"')[0]
              assert_equal(time, result['result']['_time'].to_i)
              assert_equal('fluentd_json_unixtime', result['result']['sourcetype'])
              assert_equal('default_host_test', result['result']['host'])
              assert_equal('DefaultSourceTest', result['result']['source'])
              assert_equal('default_index_test', result['result']['index'])
              assert_equal(event, JSON.parse(result['result']['_raw']))
            end

            test 'batched data with same metadata' do
              config = merge_config(test_config[:default_config_no_ack], %[
                raw false
                channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
                event_key splunk_event
                sourcetype fluentd_json_unixtime
                default_host default_host_test
                default_source DefaultSourceTest
                default_index default_index_test
              ])

              d = create_driver(config)
              time0 = Time.now.to_i - 100
              event0 = {'time' => time0, 'msg' => 'msg0'}
              record0 = {'splunk_event' => event0.to_json}
              time1 = Time.now.to_i - 200
              event1 = {'time' => time1, 'msg' => 'msg1'}
              record1 = {'splunk_event' => event1.to_json}
              d.emit(record0, time0)
              d.emit(record1, time1)
              d.run
              events = get_events(test_config[:query_port], 'source="DefaultSourceTest"', 2)
              assert_equal(time0, events[0]['result']['_time'].to_i)
              assert_equal('fluentd_json_unixtime', events[0]['result']['sourcetype'])
              assert_equal('default_host_test', events[0]['result']['host'])
              assert_equal('DefaultSourceTest', events[0]['result']['source'])
              assert_equal('default_index_test', events[0]['result']['index'])
              assert_equal(event0, JSON.parse(events[0]['result']['_raw']))
              assert_equal(time1, events[1]['result']['_time'].to_i)
              assert_equal('fluentd_json_unixtime', events[1]['result']['sourcetype'])
              assert_equal('default_host_test', events[1]['result']['host'])
              assert_equal('DefaultSourceTest', events[1]['result']['source'])
              assert_equal('default_index_test', events[1]['result']['index'])
              assert_equal(event1, JSON.parse(events[1]['result']['_raw']))
            end

            test 'batched data with diffrent metadata' do
              config = merge_config(test_config[:default_config_no_ack], %[
                raw false
                channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
                event_key splunk_event
                sourcetype fluentd_json_unixtime
                host_key key_for_host
                source_key key_for_source
                index_key key_for_index
              ])

              d = create_driver(config)
              time0 = Time.now.to_i - 100
              event0 = {'time' => time0, 'msg' => 'msg0'}
              # TODO: use values like 'index_key_test0' and 'index_key_test1'
              record0 = {'splunk_event' => event0.to_json, 'key_for_host' => 'default_host_test', 'key_for_source' => 'DefaultSourceTest', 'key_for_index' => 'default_index_test'}
              time1 = Time.now.to_i - 200
              event1 = {'time' => time1, 'msg' => 'msg1'}
              record1 = {'splunk_event' => event1.to_json, 'key_for_host' => 'host_key_test', 'key_for_source' => 'SourceKeyTest', 'key_for_index' => 'index_key_test'}
              d.emit(record0, time0)
              d.emit(record1, time1)
              d.run
              result0 = get_events(test_config[:query_port], 'source=SourceKeyTest')[0]
              assert_equal(time1, result0['result']['_time'].to_i)
              assert_equal('fluentd_json_unixtime', result0['result']['sourcetype'])
              assert_equal('host_key_test', result0['result']['host'])
              assert_equal('SourceKeyTest', result0['result']['source'])
              assert_equal('index_key_test', result0['result']['index'])
              assert_equal(event1, JSON.parse(result0['result']['_raw']))
              result1 = get_events(test_config[:query_port], 'source=DefaultSourceTest')[0]
              assert_equal(time0, result1['result']['_time'].to_i)
              assert_equal('fluentd_json_unixtime', result1['result']['sourcetype'])
              assert_equal('default_host_test', result1['result']['host'])
              assert_equal('DefaultSourceTest', result1['result']['source'])
              assert_equal('default_index_test', result1['result']['index'])
              assert_equal(event0, JSON.parse(result1['result']['_raw']))
            end

            test 'without metadata' do
              config = merge_config(test_config[:default_config_no_ack], %[
                raw false
                channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
                event_key splunk_event
              ])

              d = create_driver(config)
              time = Time.now.to_i - 100
              event = {'time' => time, 'msg' => 'msg'}
              record = {'splunk_event' => event.to_json}
              d.emit(record, time)
              d.run
              result = get_events(test_config[:query_port], "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"")[0]
              assert_equal(event, JSON.parse(result['result']['_raw']))
            end
          end

          test 'with metadata and use_fluentd_time' do
            config = merge_config(test_config[:default_config_no_ack], %[
              raw false
              channel #{[SecureRandom.hex(4), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(2), SecureRandom.hex(6)].join('-')}
              event_key splunk_event
              sourcetype fluentd_json_unixtime
              default_host default_host_test
              default_source DefaultSourceTest
              default_index default_index_test
              use_fluentd_time true
            ])

            d = create_driver(config)
            time = Time.now.to_i - 100
            event = {'time' => time, 'msg' => 'msg'}
            record = {'splunk_event' => event.to_json}
            fluentd_time = time - 100
            d.emit(record, fluentd_time)
            d.run
            result = get_events(test_config[:query_port], 'source="DefaultSourceTest"')[0]
            assert_equal(fluentd_time, result['result']['_time'].to_i)
            assert_equal('fluentd_json_unixtime', result['result']['sourcetype'])
            assert_equal('default_host_test', result['result']['host'])
            assert_equal('DefaultSourceTest', result['result']['source'])
            assert_equal('default_index_test', result['result']['index'])
            assert_equal(event, JSON.parse(result['result']['_raw']))
          end
        end
      end
    end
  end

  if SPLUNK_VERSION >= to_version('6.3.0')
    sub_test_case 'HTTPS misc' do
      teardown do
        query(8289, {'search' => "search source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\" | delete"})
      end

      sub_test_case 'with invalid certificate' do
        ## realize by changing ca_file
        test 'ssl_verify=true' do
          config = merge_config(DEFAULT_CONFIG_NO_ACK, %[
            port 8288
            use_ssl true
            ssl_verify true
            ca_file #{File.expand_path('../cert/badcacert.pem', __FILE__)}
            client_cert #{File.expand_path('../cert/client.pem', __FILE__)}
            client_key #{File.expand_path('../cert/client.key', __FILE__)}
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          # todo: shoud be able to check class and message
          assert_raise(OpenSSL::SSL::SSLError){ d.run }
          assert_raise_message(/certificate verify failed/){ d.run }
        end

        test 'ssl_verify=false' do
          config = merge_config(DEFAULT_CONFIG_NO_ACK, %[
            port 8288
            use_ssl true
            ssl_verify false
            ca_file #{File.expand_path('../cert/badcacert.pem', __FILE__)}
            client_cert #{File.expand_path('../cert/client.pem', __FILE__)}
            client_key #{File.expand_path('../cert/client.key', __FILE__)}
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          d.run
          result = get_events(8289, "source=\"#{DEFAULT_SOURCE_FOR_NO_ACK}\"")[0]
          assert_equal(time, result['result']['_time'].to_i)
          assert_equal(event, JSON.parse(result['result']['_raw']))
        end
      end

      # TODO: tests for requireClientCert=false at Splunk
      sub_test_case 'client authentication failed' do
        test 'with invalid client certificate' do
          config = merge_config(DEFAULT_CONFIG_NO_ACK, %[
            port 8288
            use_ssl true
            ssl_verify true
            ca_file #{File.expand_path('../cert/cacert.pem', __FILE__)}
            client_cert #{File.expand_path('../cert/badclient.pem', __FILE__)}
            client_key #{File.expand_path('../cert/badclient.key', __FILE__)}
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          # TODO: shoud be able to check class and message
          assert_raise(OpenSSL::SSL::SSLError){ d.run }
          assert_raise_message(/alert unknown ca/){ d.run }
        end

        test 'without client certificate' do
          config = merge_config(DEFAULT_CONFIG_NO_ACK, %[
            port 8288
            use_ssl true
            ssl_verify true
            ca_file #{File.expand_path('../cert/cacert.pem', __FILE__)}
          ])
          d = create_driver(config)
          event = {'test' => SecureRandom.hex}
          time = Time.now.to_i - 100
          d.emit(event, time)
          # TODO: shoud be able to check class and message
          assert_raise(OpenSSL::SSL::SSLError){ d.run }
          assert_raise_message(/alert handshake failure/){ d.run }
        end
      end
    end
  end
end
