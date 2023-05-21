# frozen_string_literal: true

require_relative "lib/qmap/version"

Gem::Specification.new do |spec|
  spec.name = "qmap"
  spec.version = Qmap::VERSION
  spec.authors = ["Tasos Laskos"]
  spec.email = ["tasos.laskos@gmail.com"]

  spec.summary = "Distributed NMap."
  spec.description = "Distributed NMap."
  spec.homepage = "http://ecsypno.com/"
  spec.required_ruby_version = ">= 2.6.0"

  spec.files  = Dir.glob( 'bin/*')
  spec.files += %w(bin/.gitkeep)
  spec.files += Dir.glob( 'lib/**/*')
  spec.files += Dir.glob( 'examples/**/*')
  spec.files += %w(qmap.gemspec)

  spec.add_dependency 'cuboid'
  spec.add_dependency 'ruby-nmap'
end
