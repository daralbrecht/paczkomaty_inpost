# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'paczkomaty_inpost/version'

Gem::Specification.new do |gem|
  gem.name          = "paczkomaty_inpost"
  gem.version       = PaczkomatyInpost::VERSION
  gem.authors       = ["Dariusz Albrecht"]
  gem.email         = ["dariusz.albrecht@gmail.com"]
  gem.description   = %q{API for Paczkomaty InPost}
  gem.summary       = %q{Gives access to Paczkomaty InPost API}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
