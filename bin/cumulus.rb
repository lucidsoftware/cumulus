#!/usr/bin/env ruby
module Modules
  # Public: Run the IAM module
  def self.iam
    if ARGV.size < 2 or (ARGV[1] != "diff" and ARGV[1] != "sync" and ARGV[1] != "roles" and ARGV[1] != "help")
      puts "Usage: cumulus iam [diff|help|roles|sync]"
      exit
    end

    if ARGV[1] == "help"
      puts "iam: Manage IAMs."
      puts "\tCompiles IAM roles and policies that are defined with configuration files and syncs the resulting IAM roles with AWS."
      puts
      puts "Commands"
      puts "\tdiff\t- get a list of roles that have different definitions locally than in AWS"
      puts "\troles\t- list the roles defined in configuration"
      puts "\tsync\t- sync the local role definition with AWS"
      exit
    end

    # run the application with the desired command
    require "iam/Iam"
    iam = Iam.new
    if ARGV[1] == "diff"
      if ARGV.size < 3
        iam.diff
      else
        iam.diff_one(ARGV[2])
      end
    elsif ARGV[1] == "roles"
      iam.roles
    elsif ARGV[1] == "sync"
      if ARGV.size < 3
        iam.sync
      else
        iam.sync_one(ARGV[2])
      end
    end
  end
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

# set up the application path
$LOAD_PATH.unshift(File.expand_path(
  File.join(File.dirname(__FILE__), "../lib")
))

# set up configuration for the application
require "conf/Configuration"
project_root = File.expand_path(
  File.join(File.dirname(__FILE__), "../")
)
Configuration.init(project_root, "conf/configuration.json")

if ARGV[0] == "iam"
  Modules.iam
end
