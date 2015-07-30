#!/usr/bin/env ruby

require "optparse"

module Modules
  # Public: Run the IAM module
  def self.iam
    if ARGV.size < 2 or
      (ARGV.size == 2 and ARGV[1] != "help") or
      (ARGV.size >= 3 and ((ARGV[1] != "groups" and ARGV[1] != "roles" and ARGV[1] != "users") or (ARGV[2] != "diff" and ARGV[2] != "list" and ARGV[2] != "migrate" and ARGV[2] != "sync")))
      puts "Usage: cumulus iam [help|groups|roles|users] [diff|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "iam: Manage IAMs."
      puts "\tCompiles IAM assets and policies that are defined with configuration files and syncs the resulting IAM assets with AWS."
      puts
      puts "Usage: cumulus iam [groups|help|roles|users] [diff|list|migrate|sync] <asset>"
      puts
      puts "Commands"
      puts "\tgroups - Manage IAM groups and users associated with those groups"
      puts "\t\tdiff\t- get a list of groups that have different definitions locally than in AWS (supplying the name of the group will diff only that group)"
      puts "\t\tlist\t- list the groups defined in configuration"
      puts "\t\tmigrate\t- create group configuration files that match the definitions in AWS"
      puts "\t\tsync\t- sync the local group definition with AWS (supplying the name of the group will sync only that group). Also adds and removes users from groups"
      puts "\troles - Manage IAM roles"
      puts "\t\tdiff\t- get a list of roles that have different definitions locally than in AWS (supplying the name of the role will diff only that role)"
      puts "\t\tlist\t- list the roles defined in configuration"
      puts "\t\tmigrate\t - create role configuration files that match the definitions in AWS"
      puts "\t\tsync\t- sync the local role definition with AWS (supplying the name of the role will sync only that role)"
      puts "\tusers - Manager IAM users"
      puts "\t\tdiff\t- get a list of users that have different definitions locally than in AWS (supplying the name of the user will diff only that user)"
      puts "\t\tlist\t- list the users defined in configuration"
      puts "\t\tmigrate\t - create user configuration files that match the definitions in AWS"
      puts "\t\tsync\t- sync the local user definition with AWS (supplying the name of the user will sync only that user)"
      exit
    end

    # run the application with the desired command
    require "iam/manager/Iam"
    iam = Iam.new
    resource = nil
    if ARGV[1] == "roles"
      resource = iam.roles
    elsif ARGV[1] == "users"
      resource = iam.users
    elsif ARGV[1] == "groups"
      resource = iam.groups
    end
    if ARGV[2] == "diff"
      if ARGV.size < 4
        resource.diff
      else
        resource.diff_one(ARGV[3])
      end
    elsif ARGV[2] == "list"
      resource.list
    elsif ARGV[2] == "migrate"
      resource.migrate
    elsif ARGV[2] == "sync"
      if ARGV.size < 4
        resource.sync
      else
        resource.sync_one(ARGV[3])
      end
    end
  end

  # Public: Run the AutoScaling Group module
  def self.autoscaling
    if ARGV.size < 2 or
      (ARGV.size >= 2 and ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "migrate" and ARGV[1] != "sync")
      puts "Usage: cumulus autoscaling [diff|help|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "autoscaling: Manage AutoScaling groups."
      puts "\tCompiles AutoScaling groups, scaling policies, and alarms that are defined in configuration files and syncs the resulting AutoScaling groups with AWS."
      puts
      puts "Usage: cumulus autoscaling [diff|help|list|migrate|sync] <asset>"
      puts
      puts "Commands"
      puts "\tdiff\t- print out differences between local configuration and AWS (supplying the name of an AutoScaling group will diff only that group)"
      puts "\tlist\t- list the AutoScaling groups defined locally"
      puts "\tmigrate\t- produce Cumulus configuration from current configuration in AWS"
      puts "\tsync\t- sync local AutoScaling definitions with AWS (supplying the name of an AutoScaling group will sync only that group)"
    end

    require "autoscaling/manager/AutoScaling"
    autoscaling = AutoScaling.new
    if ARGV[1] == "diff"
      if ARGV.size == 2
        autoscaling.diff
      else
        autoscaling.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "list"
      autoscaling.list
    elsif ARGV[1] == "migrate"
      autoscaling.migrate
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        autoscaling.sync
      else
        autoscaling.sync_one(ARGV[2])
      end
    end
  end

  # Public: Run the Security Group module
  def self.security
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "migrate" and ARGV[1] != "sync")
      puts "Usage: cumulus security-groups [diff|help|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "security-groups: Manage EC2 Security Groups"
      puts "\tDiff and sync EC2 security group configuration with AWS."
      puts
      puts "Usage: cumulus security-groups [diff|help|list|migrate|sync] <asset>"
      puts
      puts "Commands"
      puts "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the security group will diff only that security group)"
      puts "\tlist\t- list the locally defined security groups"
      puts "\tmigrate\t- produce Cumulus security group configuration from current AWS configuration"
      puts "\tsync\t- sync local security group definitions with AWS (supplying the name of the security group will sync only that security group)"
      exit
    end

    require "security/manager/SecurityGroups"
    security = SecurityGroups.new
    if ARGV[1] == "diff"
      if ARGV.size == 2
        security.diff
      else
        security.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "list"
      security.list
    elsif ARGV[1] == "migrate"
      security.migrate
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        security.sync
      else
        security.sync_one(ARGV[2])
      end
    end

  end
end

# check for the aws ruby gem
begin
  require 'aws-sdk'
rescue LoadError
  puts "Cumulus requires the gem 'aws-sdk'"
  puts "Please install 'aws-sdk':"
  puts "\tgem install aws-sdk -v 2.1.2"
  exit
end

if ARGV.size == 0 or (ARGV[0] != "iam" and ARGV[0] != "help" and ARGV[0] != "autoscaling" and ARGV[0] != "security-groups")
  puts "Usage: cumulus [help|iam|autoscaling|security-groups]"
  exit
end

if ARGV[0] == "help"
  puts "cumulus: AWS Configuration Manager"
  puts "\tConfiguration based management of AWS resources."
  puts
  puts "Modules"
  puts "\tiam\t\t- Compiles IAM roles and policies that are defined with configuration files and syncs the resulting IAM roles and policies with AWS"
  puts "\tautoscaling\t- Manages configuration for EC2 AutoScaling."
  puts "\tsecurity-groups\t- Manages configuration for EC2 Security Groups."
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
elsif ARGV[0] == "autoscaling"
  Modules.autoscaling
elsif ARGV[0] == "security-groups"
  Modules.security
end
