def to_version(version_str)
  Gem::Version.new(version_str)
end

SPLUNK_VERSION = to_version(ENV['SPLUNK_VERSION'])
