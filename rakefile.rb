require "bundler/gem_tasks"
require 'rspec/core/rake_task'

task :default => :spec

task :spec do
  Rake::Task['spec_sqs'].execute
end

RSpec::Core::RakeTask.new(:spec_sqs) do |task|
  task.rspec_opts = ['-r ./spec/rspec_config.rb']
  task.pattern = 'spec/sqs/*_spec.rb'
end
