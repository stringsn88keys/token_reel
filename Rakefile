# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

VERSION_FILE = File.expand_path("lib/token_reel/version.rb", __dir__)

def current_version
  File.read(VERSION_FILE).match(/VERSION = "(.*)"/)[1]
end

def write_version(new_version)
  contents = File.read(VERSION_FILE)
  updated = contents.sub(/VERSION = ".*"/, %(VERSION = "#{new_version}"))
  File.write(VERSION_FILE, updated)
end

def bumped(part)
  major, minor, patch = current_version.split(".").map(&:to_i)
  case part
  when :major then [major + 1, 0, 0]
  when :minor then [major, minor + 1, 0]
  when :patch then [major, minor, patch + 1]
  end.join(".")
end

desc "Print the current version"
task :version do
  puts current_version
end

namespace :version do
  desc "Bump major version (X.0.0) -- breaking changes"
  task :major do
    old_version = current_version
    new_version = bumped(:major)
    write_version(new_version)
    puts "#{old_version} -> #{new_version} (lib/token_reel/version.rb updated, not committed)"
  end

  desc "Bump minor version (x.X.0) -- backwards-compatible features"
  task :minor do
    old_version = current_version
    new_version = bumped(:minor)
    write_version(new_version)
    puts "#{old_version} -> #{new_version} (lib/token_reel/version.rb updated, not committed)"
  end

  desc "Bump patch version (x.x.X) -- backwards-compatible fixes"
  task :patch do
    old_version = current_version
    new_version = bumped(:patch)
    write_version(new_version)
    puts "#{old_version} -> #{new_version} (lib/token_reel/version.rb updated, not committed)"
  end
end
