# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sape-rails/version'

Gem::Specification.new do |gem|
  gem.name          = "sape-rails"
  gem.version       = Sape::VERSION
  gem.authors       = ["Boris Chernov"]
  gem.email         = ["boris@imode.lv"]
  gem.description   = %q{Display sape.ru links}
  gem.summary       = %q{}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
