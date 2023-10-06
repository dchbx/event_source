# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)

$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'event_source/version'

Gem::Specification.new do |spec|
  spec.name = 'event_source'
  spec.version = EventSource::VERSION
  spec.authors = ['Dan Thomas']
  spec.email = ['info@dchbx.com']

  spec.summary =
    'Record changes to application state by storing updates as a sequence of events'
  spec.description =
    "This service uses Mogoid/MongoDB to create an event object to record a state change and
                          then processes it to update values in the underlying model. It's an implementation of
                          Martin Fowler's Event Sourcing design pattern and adapted from code developed by
                          Philippe Creux"
  spec.homepage = 'https://github.com/dchbx/event_source'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5')

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(File.expand_path('..', __FILE__)) do
      `git ls-files -z`.split("\x0").reject do |f|
        f.match(%r{^(test|spec|features)/})
      end
    end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'addressable', '>= 2.8.0'
  spec.add_dependency 'bunny', '>= 2.14'
  spec.add_dependency 'deep_merge', '~> 1.2.0'
  spec.add_dependency 'dry-configurable', '~> 0.12'
  spec.add_dependency 'dry-events', '~> 0.3'
  spec.add_dependency 'dry-inflector', '~> 0.2'
  spec.add_dependency 'dry-initializer', '~> 3.0'
  spec.add_dependency 'dry-monads', '~> 1.3'
  spec.add_dependency 'dry-struct', '~> 1.4'
  spec.add_dependency 'dry-types', '~> 1.5'
  spec.add_dependency 'dry-validation', '~> 1.6'
  spec.add_dependency 'dry-schema', '~> 1.6'
  spec.add_dependency 'faraday', '~> 1.4.1'
  spec.add_dependency 'faraday_middleware', '~> 1.0'
  spec.add_dependency 'logging', '~> 2.3.0'
  spec.add_dependency 'nokogiri', '>= 1.13.0'
  spec.add_dependency 'mime-types'
  spec.add_dependency 'oj', '~> 3.11'
  spec.add_dependency 'ox', '~> 2.14'
  spec.add_dependency 'resque-bus', '~> 0.7.0'
  spec.add_dependency 'typhoeus', '~> 1.4.0'

  # TODO: Change to development dependency
  spec.add_development_dependency 'database_cleaner'
  spec.add_development_dependency 'faker'
  spec.add_development_dependency 'mongoid'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'sinatra'
end
