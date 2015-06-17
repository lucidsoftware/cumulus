#!/usr/bin/env ruby

require "optparse"

module Modules
  # Public: Run the IAM module
  def self.iam
    if ARGV.size < 2 or
      (ARGV.size == 2 and ARGV[1] != "help") or
      (ARGV.size >= 3 and ((ARGV[1] != "roles" and ARGV[1] != "users") or (ARGV[2] != "diff" and ARGV[2] != "list" and ARGV[2] != "sync")))
      puts "Usage: cumulus iam [help|roles|users] [diff|list|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "iam: Manage IAMs."
      puts "\tCompiles IAM assets and policies that are defined with configuration files and syncs the resulting IAM assets with AWS."
      puts
      puts "Usage: cumulus iam [help|roles|users] [diff|list|sync] <asset>"
      puts
      puts "Commands"
      puts "\troles - Manage IAM roles"
      puts "\t\tdiff\t- get a list of roles that have different definitions locally than in AWS (supplying the name of the role will diff only that role)"
      puts "\t\tlist\t- list the roles defined in configuration"
      puts "\t\tsync\t- sync the local role definition with AWS (supplying the name of the role will sync only that role)"
      puts "\tusers - Manager IAM users"
      puts "\t\tdiff\t- get a list of users that have different definitions locally than in AWS (supplying the name of the user will diff only that user)"
      puts "\t\tlist\t- list the users defined in configuration"
      puts "\t\tsync\t- sync the local user definition with AWS (supplying the name of the user will sync only that user)"
      exit
    end

    # run the application with the desired command
    require "iam/Iam"
    iam = Iam.new
    resource = nil
    if ARGV[1] == "roles"
      resource = iam.roles
    elsif ARGV[1] == "users"
      resource = iam.users
    end
    if ARGV[2] == "diff"
      if ARGV.size < 4
        resource.diff
      else
        resource.diff_one(ARGV[3])
      end
    elsif ARGV[2] == "list"
      resource.list
    elsif ARGV[2] == "sync"
      if ARGV.size < 4
        resource.sync
      else
        resource.sync_one(ARGV[3])
      end
    end
  end
end

# check for the aws ruby gem
begin
  require 'aws-sdk'
rescue LoadError
  puts "Cumulus requires the gem 'aws-sdk'"
  puts "Please install 'aws-sdk'"
  exit
end

if ARGV.size == 0 or (ARGV[0] != "iam" and ARGV[0] != "help")
  puts "Usage: cumulus [iam|help]"
  exit
end

if ARGV[0] == "help"
  puts "cumulus: AWS Configuration Manager"
  puts "\tConfiguration based management of AWS resources."
  puts
  puts "Modules"
  puts "\tiam\t- Compiles IAM roles and policies that are defined with configuration files and syncs the resulting IAM roles and policies with AWS"
end

# read in the optional path to the configuration file to use
options = {
  :config => "conf/configuration.json",
  :root => nil
}
OptionParser.new do |opts|
  opts.on("-c", "--config [FILE]", "Specify the configuration file to use") do |c|
    options[:config] = c
  end

  opts.on("-r", "--root [DIR]", "Specify the project root to use") do |r|
    options[:root] = r
  end
end.parse!

# config parameters can also be read in from environment variables
if !ENV["CUMULUS_CONFIG"].nil?
  options[:config] = ENV["CUMULUS_CONFIG"]
end

if !ENV["CUMULUS_ROOT"].nil?
  options[:root] = ENV["CUMULUS_ROOT"]
end

# set up the application path
$LOAD_PATH.unshift(File.expand_path(
  File.join(File.dirname(__FILE__), "../lib")
))

# set up configuration for the application
require "conf/Configuration"
project_root = File.expand_path(
  File.join(File.dirname(__FILE__), "../")
)
if !options[:root].nil?
  project_root = File.expand_path(options[:root])
end
Configuration.init(project_root, options[:config])

if ARGV[0] == "iam"
  Modules.iam
end
