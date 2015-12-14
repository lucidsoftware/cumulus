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
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "sync" and ARGV[1] != "invalidate" and ARGV[1] != "migrate")
      puts "Usage: cumulus cloudfront [diff|help|invalidate|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "cloudfront: Manage CloudFront"
      puts "\tDiff and sync CloudFront configuration with AWS."
      puts
      puts "Usage: cumulus cloudfront [diff|help|invalidate|list] <asset>"
      puts "Commands"
      puts "\tdiff\t\t- print out differences between local configuration and AWS (supplying the id of the distribution will diff only that distribution)"
      puts "\tinvalidate\t- create an invalidation.  Must supply the name of the invalidation to run.  Specifying 'list' as an argument lists the local invalidation configurations"
      puts "\tlist\t\t- list the locally defined distributions"
      puts "\tmigrate\t\t- produce Cumulus CloudFront distribution configuration from current AWS configuration"
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
        if ARGV[2] == "list"
          cloudfront.list_invalidations
        else
          cloudfront.invalidate(ARGV[2])
        end
      end
    elsif ARGV[1] == "migrate"
      cloudfront.migrate
    end

  end

  # Public: Run the S3 module
  def self.s3
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "migrate" and ARGV[1] != "sync")
      puts "Usage: cumulus s3 [diff|help|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "s3: Manage S3 Buckets"
      puts "\tDiff and sync S3 bucket configuration with AWS."
      puts
      puts "Usage: cumulus s3 [diff|help|list|migrate|sync] <asset>"
      puts
      puts "Commands"
      puts "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the bucket will diff only that bucket)"
      puts "\tlist\t- list the locally defined S3 buckets"
      puts "\tmigrate\t- produce Cumulus S3 configuration from current AWS configuration"
      puts "\tsync\t- sync local bucket definitions with AWS (supplying the name of the bucket will sync only that bucket)"
      exit
    end

    require "s3/manager/Manager"
    s3 = Cumulus::S3::Manager.new
    if ARGV[1] == "diff"
      if ARGV.size == 2
        s3.diff
      else
        s3.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "list"
      s3.list
    elsif ARGV[1] == "migrate"
      s3.migrate
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        s3.sync
      else
        s3.sync_one(ARGV[2])
      end
    end
  end

  # Public: Run the elb module
  def self.elb
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "sync" and ARGV[1] != "migrate")
      puts "Usage: cumulus elb [diff|help|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "elb: Manage Elastic Load Balancers"
      puts "\tDiff and sync ELB configuration with AWS."
      puts
      puts "Usage: cumulus elb [diff|help|list|migrate|sync] <asset>"
      puts
      puts "Commands"
      puts "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the elb will diff only that elb)"
      puts "\tlist\t- list the locally defined ELBs"
      puts "\tsync\t- sync local ELB definitions with AWS (supplying the name of the elb will sync only that elb)"
      puts "\tmigrate\t- migrate AWS configuration to Cumulus"
      puts "\t\tdefault-policies- migrate default ELB policies from AWS to Cumulus"
      puts "\t\telbs\t\t- migrate the current ELB configuration from AWS to Cumulus"
      exit
    end

    require "elb/manager/Manager"
    elb = Cumulus::ELB::Manager.new()
    if ARGV[1] == "diff"
      if ARGV.size == 2
        elb.diff
      else
        elb.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "list"
      elb.list
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        elb.sync
      else
        elb.sync_one(ARGV[2])
      end
    elsif ARGV[1] == "migrate"
      if ARGV[2] == "default-policies"
        elb.migrate_default_policies
      elsif ARGV[2] == "elbs"
        elb.migrate_elbs
      else
        puts "Usage: cumulus elb migrate [default-policies|elbs]"
      end
    end
  end

  # Public: Run the vpc module
  def self.vpc
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "sync" and ARGV[1] != "migrate" and ARGV[1] != "rename")
      puts "Usage: cumulus vpc [diff|help|list|migrate|sync|rename] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "vpc: Manage Virtual Private Cloud"
      puts "\tDiff and sync VPC configuration with AWS."
      puts
      puts "Usage: cumulus vpc [diff|help|list|migrate|sync|rename] <asset>"
      puts
      puts "Commands"
      puts "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the VPC will diff only that VPC)"
      puts "\tlist\t- list the locally defined VPCs"
      puts "\tsync\t- sync local VPC definitions with AWS (supplying the name of the VPC will sync only that VPC)"
      puts "\tmigrate\t- migrate AWS configuration to Cumulus"
      puts "\trename\t- renames a cumulus asset and all references to it"
      exit
    end

    require "vpc/manager/Manager"
    vpc = Cumulus::VPC::Manager.new
    if ARGV[1] == "diff"
      if ARGV.size == 2
        vpc.diff
      else
        vpc.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        vpc.sync
      else
        vpc.sync_one(ARGV[2])
      end
    elsif ARGV[1] == "list"
      vpc.list
    elsif ARGV[1] == "migrate"
      vpc.migrate
    elsif ARGV[1] == "rename"
      if ARGV.size == 5
        vpc.rename(ARGV[2], ARGV[3], ARGV[4])
      else
        puts "Usage: cumulus vpc rename [network-acl|policy|route-table|subnet|vpc] <old-asset-name> <new-asset-name>"
      end
    end
  end

  # Public: Run the kinesis module
  def self.kinesis
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "sync" and ARGV[1] != "migrate")
      puts "Usage: cumulus kinesis [diff|help|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "kinesis: Manage Kinesis Streams"
      puts "\tDiff and sync Kinesis configuration with AWS."
      puts
      puts "Usage: cumulus kinesis [diff|help|list|migrate|sync] <asset>"
      puts
      puts "Commands"
      puts "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the stream will diff only that stream)"
      puts "\tlist\t- list the locally defined VPCs"
      puts "\tsync\t- sync local stream definitions with AWS (supplying the name of the stream will sync only that stream)"
      puts "\tmigrate\t- migrate AWS configuration to Cumulus"
      exit
    end

    require "kinesis/manager/Manager"
    kinesis = Cumulus::Kinesis::Manager.new
    if ARGV[1] == "diff"
      if ARGV.size == 2
        kinesis.diff
      else
        kinesis.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        kinesis.sync
      else
        kinesis.sync_one(ARGV[2])
      end
    elsif ARGV[1] == "list"
      kinesis.list
    elsif ARGV[1] == "migrate"
      kinesis.migrate
    end
  end

  # Public: Run the SQS module
  def self.sqs
    if ARGV.size < 2 or (ARGV[1] != "help" and ARGV[1] != "diff" and ARGV[1] != "list" and ARGV[1] != "urls" and ARGV[1] != "sync" and ARGV[1] != "migrate")
      puts "Usage: cumulus sqs [diff|help|list|migrate|sync|urls] <asset>"
    end

    if ARGV[1] == "help"
      puts "SQS: Manage SQS"
      puts "\tDiff and sync SQS configuration with AWS."
      puts
      puts "Usage: cumulus sqs [diff|help|list|migrate|sync|urls] <asset>"
      puts
      puts "Commands"
      puts "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the queue will diff only that queue)"
      puts "\tlist\t- list the locally defined queues"
      puts "\turls\t- list the url for each locally defined queue"
      puts "\tsync\t- sync local queue definitions with AWS (supplying the name of the queue will sync only that queue)"
      puts "\tmigrate\t- migrate AWS configuration to Cumulus"
      exit
    end

    require "sqs/manager/Manager"
    sqs = Cumulus::SQS::Manager.new
    if ARGV[1] == "diff"
      if ARGV.size == 2
        sqs.diff
      else
        sqs.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "sync"
      if ARGV.size == 2
        sqs.sync
      else
        sqs.sync_one(ARGV[2])
      end
    elsif ARGV[1] == "list"
      sqs.list
    elsif ARGV[1] == "urls"
      sqs.urls
    elsif ARGV[1] == "migrate"
      sqs.migrate
    end
  end

  # Public: Run the EC2 module
  def self.ec2
    if ARGV.size < 2 or
      (ARGV.size == 2 and ARGV[1] != "help") or
      (ARGV.size >= 3 and ((ARGV[1] != "ebs" and ARGV[1] != "instances") or (ARGV[2] != "diff" and ARGV[2] != "list" and ARGV[2] != "migrate" and ARGV[2] != "sync")))
      puts "Usage: cumulus ec2 [help|ebs|instances] [diff|list|migrate|sync] <asset>"
      exit
    end

    if ARGV[1] == "help"
      puts "ec2: Manage EC2 instances and related configuration."
      puts
      puts "Usage: cumulus ec2 [help|ebs|instances] [diff|list|migrate|sync] <asset>"
      puts
      puts "Commands"
      puts "\tebs - Manage EBS volumes in groups"
      puts "\t\tdiff\t- get a list of groups that have different definitions locally than in AWS (supplying the name of the group will diff only that group)"
      puts "\t\tlist\t- list the groups defined in configuration"
      puts "\t\tmigrate\t- create group configuration files that match the definitions in AWS"
      puts "\t\tsync\t- sync the local group definition with AWS (supplying the name of the group will sync only that group). Also creates volumes in a group"
      puts "\tinstances - Manage EC2 instances"
      puts "\t\tdiff\t- get a list of instances that have different definitions locally than in AWS (supplying the name of the instance will diff only that instance)"
      puts "\t\tlist\t- list the instances defined in configuration"
      puts "\t\tmigrate\t - create instances configuration files that match the definitions in AWS"
      puts "\t\tsync\t- sync the local instance definition with AWS (supplying the name of the instance will sync only that instance)"
      exit
    end

    require "ec2/managers/EbsManager"
    require "ec2/managers/InstanceManager"

    # Get the manager depending on which submodule is ran
    manager = nil
    if ARGV[1] == "ebs"
      manager = Cumulus::EC2::EbsManager.new
    elsif ARGV[1] == "instances"
      manager = Cumulus::EC2::InstanceManager.new
    end

    # Run actions on the manager
    if ARGV[2] == "diff"
      if ARGV.size < 4
        manager.diff
      else
        manager.diff_one(ARGV[3])
      end
    elsif ARGV[2] == "list"
      manager.list
    elsif ARGV[2] == "migrate"
      manager.migrate
    elsif ARGV[2] == "sync"
      if ARGV.size < 4
        manager.sync
      else
        manager.sync_one(ARGV[3])
      end
    end
  end

end

# read in the optional path to the configuration file to use
options = {
  :config => "conf/configuration.json",
  :root => nil,
  :profile => nil,
  :autoscaling_force_size => false
}
OptionParser.new do |opts|
  opts.on("-c", "--config [FILE]", "Specify the configuration file to use") do |c|
    options[:config] = c
  end

  opts.on("-r", "--root [DIR]", "Specify the project root to use") do |r|
    options[:root] = r
  end

  opts.on("-p", "--aws-profile [NAME]", "Specify the AWS profile to use for API requests") do |p|
    options[:profile] = p
  end

  opts.on("--autoscaling-force-size", "Forces autoscaling to use configured min/max/desired values instead of scheduled actions") do |f|
    options[:autoscaling_force_size] = true
  end
end.parse!

# config parameters can also be read in from environment variables
if !ENV["CUMULUS_CONFIG"].nil?
  options[:config] = ENV["CUMULUS_CONFIG"]
end

if !ENV["CUMULUS_ROOT"].nil?
  options[:root] = ENV["CUMULUS_ROOT"]
end

if !ENV["CUMULUS_AWS_PROFILE"].nil?
  options[:profile] = ENV["CUMULUS_AWS_PROFILE"]
end

# set up the application path
$LOAD_PATH.unshift(File.expand_path(
  File.join(File.dirname(__FILE__), "../lib")
))

require "util/patches"

# set up configuration for the application
require "conf/Configuration"
project_root = File.expand_path(
  File.join(File.dirname(__FILE__), "../")
)
if !options[:root].nil?
  project_root = File.expand_path(options[:root])
end
Cumulus::Configuration.init(project_root, options[:config], options[:profile], options[:autoscaling_force_size])

if ARGV.size == 0 or (ARGV[0] != "iam" and ARGV[0] != "help" and ARGV[0] != "autoscaling" and
  ARGV[0] != "route53" and ARGV[0] != "s3" and ARGV[0] != "security-groups" and
  ARGV[0] != "cloudfront" and ARGV[0] != "elb" and ARGV[0] != "vpc" and ARGV[0] != "kinesis" and
  ARGV[0] != "sqs" and ARGV[0] != "ec2")
  puts "Usage: cumulus [autoscaling|cloudfront|ec2|elb|help|iam|kinesis|route53|s3|security-groups|sqs|vpc]"
  exit
end

if ARGV[0] == "help"
  puts "cumulus: AWS Configuration Manager"
  puts "\tConfiguration based management of AWS resources."
  puts
  puts "Modules"
  puts "\tautoscaling\t- Manages configuration for EC2 AutoScaling"
  puts "\tcloudfront\t- Manages configuration for cloudfront distributions"
  puts "\tec2\t\t- Manages configuration for managed EC2 instances, EBS volumes and Network Interfaces"
  puts "\telb\t\t- Manages configuration for elastic load balancers"
  puts "\tiam\t\t- Compiles IAM roles and policies that are defined with configuration files and syncs the resulting IAM roles and policies with AWS"
  puts "\tkinesis\t- Manages configuration for Kinesis streams"
  puts "\troute53\t\t- Manages configuration for Route53"
  puts "\ts3\t\t- Manages configuration of S3 buckets"
  puts "\tsecurity-groups\t- Manages configuration for EC2 Security Groups"
  puts "\tsqs\t\t- Manages configuration for SQS Queues"
  puts "\tvpc\t\t- Manages configuration for Virtual Private Clouds"
end

if ARGV[0] == "iam"
  Modules.iam
elsif ARGV[0] == "autoscaling"
  Modules.autoscaling
elsif ARGV[0] == "cloudfront"
  Modules.cloudfront
elsif ARGV[0] == "ec2"
  Modules.ec2
elsif ARGV[0] == "elb"
  Modules.elb
elsif ARGV[0] == "kinesis"
  Modules.kinesis
elsif ARGV[0] == "route53"
  Modules.route53
elsif ARGV[0] == "security-groups"
  Modules.security
elsif ARGV[0] == "s3"
  Modules.s3
elsif ARGV[0] == "sqs"
  Modules.sqs
elsif ARGV[0] == "vpc"
  Modules.vpc
end
