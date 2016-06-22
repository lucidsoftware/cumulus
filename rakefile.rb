require "bundler/gem_tasks"
require 'rspec/core/rake_task'

task :default => :spec

RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = ['-r ./spec/rspec_config.rb']
  task.pattern = 'spec/sqs/*_spec.rb'
end
