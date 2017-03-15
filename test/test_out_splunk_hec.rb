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

  def create_driver(conf)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::SplunkHECOutput).configure(conf)
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

  sub_test_case 'HTTP' do
    teardown do
      query(8089, {'search' => 'search source="http:FluentTestNoAck" | delete'})
      query(8089, {'search' => 'search source="http:FluentTestAck" | delete'})
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
      query(8289, {'search' => 'search source="http:FluentTestNoAck" | delete'})
      query(8289, {'search' => 'search source="http:FluentTestAck" | delete'})
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
