#!/usr/bin/env ruby

require "optparse"

module Modules
  # Public: Run the IAM module
  def self.iam
    if ARGV.size < 2 or
      (ARGV.size == 2 and ARGV[1] != "help") or
      (ARGV.size >= 3 and ((ARGV[1] != "groups" and ARGV[1] != "roles" and ARGV[1] != "users" and ARGV[1]) or (ARGV[2] != "diff" and ARGV[2] != "list" and ARGV[2] != "migrate" and ARGV[2] != "sync")))
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
    require "iam/manager/Manager"
    iam = Cumulus::IAM::Manager.new
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

    require "autoscaling/manager/Manager"
    autoscaling = Cumulus::AutoScaling::Manager.new
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

  # Public: Run the route53 module
  def self.route53
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "migrate" and ARGV[1] != "sync")
      puts "Usage: cumulus route53 [diff|help|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "route53: Manage Route53"
      puts "\tDiff and sync Route53 configuration with AWS."
      puts
      puts "Usage: cumulus route53 [diff|help|list|migrate|sync] <asset>"
      puts "Commands"
      puts "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the zone will diff only that zone)"
      puts "\tlist\t- list the locally defined zones"
      puts "\tmigrate\t- produce Cumulus zone configuration from current AWS configuration"
      puts "\tsync\t- sync local zone definitions with AWS (supplying the name of the zone will sync only that zone)"
      exit
    end

    require "route53/manager/Manager"
    route53 = Cumulus::Route53::Manager.new
    if ARGV[1] == "diff"
      if ARGV.size == 2
        route53.diff
      else
        route53.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "list"
      route53.list
    elsif ARGV[1] == "migrate"
      route53.migrate
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        route53.sync
      else
        route53.sync_one(ARGV[2])
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

    require "security/manager/Manager"
    security = Cumulus::SecurityGroups::Manager.new
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

  # Public: Run the Cloudfront module
  def self.cloudfront
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "sync" and ARGV[1] != "invalidate")
      puts "Usage: cumulus cloudfront [diff|help|invalidate|list|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "cloudfront: Manage CloudFront"
      puts "\tDiff and sync CloudFront configuration with AWS."
      puts
      puts "Usage: cumulus cloudfront [diff|help|invalidate|list] <asset>"
      puts "Commands"
      puts "\tdiff\t\t- print out differences between local configuration and AWS (supplying the id of the distribution will diff only that distribution)"
      puts "\tinvalidate\t- create an invalidation.  Must supply the name of the invalidation to run"
      puts "\tlist\t\t- list the locally defined distributions"
      puts "\tsync\t\t- sync local cloudfront distribution configuration with AWS (supplying the id of the distribution will sync only that distribution)"
      exit
    end

    require "cloudfront/manager/Manager"

    cloudfront = Cumulus::CloudFront::Manager.new

    if ARGV[1] == "list"
      cloudfront.list
    elsif ARGV[1] == "diff"
      if ARGV.size == 2
        cloudfront.diff
      else
        cloudfront.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        cloudfront.sync
      else
        cloudfront.sync_one(ARGV[2])
      end
    elsif ARGV[1] == "invalidate"
      if ARGV.size != 3
        puts "Specify one invalidation to run"
        exit
      else
        cloudfront.invalidate(ARGV[2])
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

if ARGV.size == 0 or (ARGV[0] != "iam" and ARGV[0] != "help" and ARGV[0] != "autoscaling" and
  ARGV[0] != "route53" and ARGV[0] != "security-groups" and ARGV[0] != "cloudfront")
  puts "Usage: cumulus [autoscaling|cloudfront|help|iam|route53|security-groups]"
  exit
end

if ARGV[0] == "help"
  puts "cumulus: AWS Configuration Manager"
  puts "\tConfiguration based management of AWS resources."
  puts
  puts "Modules"
  puts "\tautoscaling\t- Manages configuration for EC2 AutoScaling"
  puts "\tcloudfront\t- Manages configuration for cloudfront distributions"
  puts "\tiam\t\t- Compiles IAM roles and policies that are defined with configuration files and syncs the resulting IAM roles and policies with AWS"
  puts "\troute53\t\t- Manages configuration for Route53"
  puts "\tsecurity-groups\t- Manages configuration for EC2 Security Groups"
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
Cumulus::Configuration.init(project_root, options[:config])

if ARGV[0] == "iam"
  Modules.iam
elsif ARGV[0] == "autoscaling"
  Modules.autoscaling
elsif ARGV[0] == "cloudfront"
  Modules.cloudfront
elsif ARGV[0] == "route53"
  Modules.route53
elsif ARGV[0] == "security-groups"
  Modules.security
end
