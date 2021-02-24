# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-splunk-enterprise"
  spec.version       = "0.10.2"
  spec.authors       = ["Yuki Ito", "Masahiro Nakagawa"]
  spec.email         = ["yito@treasure-data.com", "repeatedly@gmail.com"]

  spec.summary       = %q{Splunk output plugin for Fluentd}
  spec.description   = spec.summary
  spec.homepage      = ""
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'fluentd', [">= 1"]
  spec.add_dependency 'json'
  spec.add_dependency 'httpclient'

  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "test-unit", ">= 3.0.8"
  spec.add_development_dependency "simplecov", ">= 0.10.0"
end
