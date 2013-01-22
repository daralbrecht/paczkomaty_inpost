# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'paczkomaty_inpost/version'

Gem::Specification.new do |gem|
  gem.authors       = ["Dariusz Albrecht"]
  gem.email         = ["dariusz.albrecht@gmail.com"]
  gem.description   = %q{API for Paczkomaty InPost}
  gem.summary       = %q{Gives access to Paczkomaty InPost API}
  gem.homepage      = ""

  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split($/)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "paczkomaty_inpost"
  gem.require_paths = ["lib"]
  gem.version       = PaczkomatyInpost::VERSION

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'

  gem.add_dependency 'nokogiri'
end
