# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name              = 'mongodb-activerecord-adapter'
  s.version           = '0.1'
  s.platform          = Gem::Platform::RUBY
  s.authors           = [ 'Jamis Buck <jamis.buck@mongodb.com>' ]
  s.summary           = 'MongoDB adapter for ActiveRecord'
  s.description       = 'MongoDB adapter for ActiveRecord'
  s.license           = 'MIT'

  s.files             = Dir.glob('{examples,lib}/**/*')
  s.files             += %w[mongodb-activerecord-adapter.gemspec Gemfile LICENSE README.md]

  s.require_paths     = %w[ lib ]

  s.required_ruby_version = '>= 3.0'

  s.add_dependency 'activerecord', '~> 7.1'
  s.add_dependency 'mongo'
end
