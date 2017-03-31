def to_version(version_str)
  Gem::Version.new(version_str)
end

SPLUNK_VERSION = to_version(ENV['SPLUNK_VERSION'])

## query(8088, 'source="SourceName"')
def get_events(port, search_query, expected_num = 1)
  retries = 0
  events = []
  while events.length != expected_num
    print '-' unless retries == 0
    sleep(3)
    events = query(port, {'search' => 'search ' + search_query})
    retries += 1
    raise "exceed query retry limit" if retries > 20
  end
  events
end

def query(port, q)
  uri = URI.parse("https://127.0.0.1:#{port}/services/search/jobs/export")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.cert = OpenSSL::X509::Certificate.new(File.read(File.expand_path('../cert/client.pem', __FILE__)))
  http.key = OpenSSL::PKey::RSA.new(File.read(File.expand_path('../cert/client.key', __FILE__)))
  req = Net::HTTP::Post.new(uri.path)
  req.basic_auth('admin', 'changeme')
  req.set_form_data(q.merge({'output_mode' => 'json', 'time_format' => '%s'}))
  http.request(req).body.split("\n").map{|line| JSON.parse(line)}.delete_if{|json| json['lastrow']}
end
