# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ovsimager/version'

Gem::Specification.new do |spec|
  spec.name          = "ovsimager"
  spec.version       = OVSImager::VERSION
  spec.authors       = ["NeoCat"]
  spec.email         = ["neocat@neocat.jp"]
  spec.summary       = %q{Draw graph of Open vSwitch virtual bridges.}
  spec.description   = %q{OVSImager draws a graph that describes relationship among Open vSwitch bridges, Linux bridges, and namespaces for routing. It can also mark the ports where ping packets went through using tcpdump, which is a useful feature for trouble-shooting in SDN environments. }
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
