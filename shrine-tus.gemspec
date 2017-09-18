Gem::Specification.new do |gem|
  gem.name          = "shrine-tus"
  gem.version       = "1.0.0"

  gem.required_ruby_version = ">= 2.1"

  gem.summary      = "Provides storage and plugin for easier integration between Shrine and tus-ruby-server."
  gem.homepage     = "https://github.com/janko-m/shrine-tus"
  gem.authors      = ["Janko Marohnić"]
  gem.email        = ["janko.marohnic@gmail.com"]
  gem.license      = "MIT"

  gem.files        = Dir["README.md", "LICENSE.txt", "lib/**/*.rb", "*.gemspec"]
  gem.require_path = "lib"

  gem.add_dependency "shrine", "~> 2.0"
  gem.add_dependency "tus-server", "~> 1.0"
  gem.add_dependency "shrine-url", "~> 1.0"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "minitest"
  gem.add_development_dependency "shrine-gridfs"
  gem.add_development_dependency "aws-sdk-s3", "~> 1.2"
  gem.add_development_dependency "webmock"
end
