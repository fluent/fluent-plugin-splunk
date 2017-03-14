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

  def create_driver(conf)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::SplunkTCPOutput).configure(conf)
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

  sub_test_case 'TCP' do
    teardown do
      query(8089, {'search' => 'search source="tcp:12300" | delete'})
    end

    test 'emit' do
      config = %[
        host 127.0.0.1
        port 12300
        ssl_verify_peer false
      ]
      d = create_driver(config)
      event = {'test' => SecureRandom.hex}
      time = Time.now.to_i
      d.emit(event, time)
      d.run
      sleep(3)
      result = get_events(8089, 'tcp:12300')[0]
      assert_equal(time, result['result']['_time'].to_i)
      assert_equal(event.merge({'time' => time}), JSON.parse(result['result']['_raw']))
    end
  end

  sub_test_case 'SSL' do
    teardown do
      query(8289, {'search' => 'search source="tcp:12500" | delete'})
    end

    test 'emit' do
      config = %[
        host 127.0.0.1
        port 12500
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
      result = get_events(8289, 'tcp:12500')[0]
      assert_equal(time, result['result']['_time'].to_i)
      assert_equal(event.merge({'time' => time}), JSON.parse(result['result']['_raw']))
    end
  end
end
