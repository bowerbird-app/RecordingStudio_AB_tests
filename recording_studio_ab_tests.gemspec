# frozen_string_literal: true

require_relative "lib/recording_studio_ab_tests/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_ab_tests"
  spec.version     = RecordingStudioAbTests::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_AB_tests"
  spec.summary     = "Server-side A/B testing for Recording Studio hosts"
  spec.description = "Sticky server-side A/B experiments: targets, allocation, exposures, and conversions."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_AB_tests"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_AB_tests/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
