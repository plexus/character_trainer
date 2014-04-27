# encoding: utf-8

#require File.expand_path('../lib/character_trainer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = 'character_trainer'
  gem.version     = '0.0.0'
  gem.authors     = [ 'Arne Brasseur' ]
  gem.email       = [ 'arne@arnebrasseur.net' ]
  gem.description = 'Chinese Character Trainer with Spaced Repetition.'
  gem.summary     = gem.description
  gem.homepage    = 'https://github.com/plexus/character_trainer'
  gem.license     = 'GPL-2'

  gem.require_paths    = %w[lib]
  gem.files            = `git ls-files`.split($/)
  gem.test_files       = `git ls-files -- spec`.split($/)
  gem.extra_rdoc_files = %w[README.md]

  gem.add_runtime_dependency 'engine', '~> 0.0.0'
  gem.add_runtime_dependency 'pry'
  gem.add_runtime_dependency 'rainbow', '~> 2.0'

  # gem.add_development_dependency 'rake', '~> 10.1'
  # gem.add_development_dependency 'rspec', '~> 2.14'
end
