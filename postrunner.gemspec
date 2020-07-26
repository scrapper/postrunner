# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'postrunner/version'

GEM_SPEC = Gem::Specification.new do |spec|
  spec.name          = "postrunner"
  spec.version       = PostRunner::VERSION
  spec.authors       = ["Chris Schlaeger"]
  spec.email         = ["cs@taskjuggler.org"]
  spec.summary       = %q{Application to manage and analyze Garmin FIT files.}
  spec.description   = %q{PostRunner is an application to manage FIT files
such as those produced by Garmin products like the Forerunner 620 (FR620),
Forerunner 25 (FR25), Fenix 3, Fenix 3HR, Fenix 5 (S and X). It allows you to
import the files from the device and analyze the data. In addition to the
common features like plotting pace, heart rates, elevation and other captured
values it also provides a heart rate variability (HRV) and sleep analysis. It
can also update satellite orbit prediction (EPO) data on the device to
speed-up GPS fix times.  It is an offline alternative to Garmin Connect. The
software has been developed and tested on Linux but should work on other
operating systems as well.}
  spec.homepage      = 'https://github.com/scrapper/postrunner'
  spec.license       = "GNU GPL version 2"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '>=2.4'

  spec.add_dependency 'fit4ruby', '~> 3.6.0'
  spec.add_dependency 'perobs', '~> 4.2.0'
  spec.add_dependency 'nokogiri', '~> 1.6'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 0.9.6'
  spec.add_development_dependency 'rspec', '~> 3.6.0'
  spec.add_development_dependency 'yard', '~> 0.9.20'
end
