module Cumulus
  module IAM
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.command_details
        [
          "\tgroups - Manage IAM groups and users associated with those groups",
          "\t\tdiff\t- get a list of groups that have different definitions locally than in AWS (supplying the name of the group will diff only that group)",
          "\t\tlist\t- list the groups defined in configuration",
          "\t\tmigrate\t- create group configuration files that match the definitions in AWS",
          "\t\tsync\t- sync the local group definition with AWS (supplying the name of the group will sync only that group). Also adds and removes users from groups",
          "\troles - Manage IAM roles",
          "\t\tdiff\t- get a list of roles that have different definitions locally than in AWS (supplying the name of the role will diff only that role)",
          "\t\tlist\t- list the roles defined in configuration",
          "\t\tmigrate\t - create role configuration files that match the definitions in AWS",
          "\t\tsync\t- sync the local role definition with AWS (supplying the name of the role will sync only that role)",
          "\tusers - Manage IAM users",
          "\t\tdiff\t- get a list of users that have different definitions locally than in AWS (supplying the name of the user will diff only that user)",
          "\t\tlist\t- list the users defined in configuration",
          "\t\tmigrate\t - create user configuration files that match the definitions in AWS",
          "\t\tsync\t- sync the local user definition with AWS (supplying the name of the user will sync only that user)",
        ].join("\n")
      end

      def self.valid_options
        [["groups", "roles", "users"], ["diff", "list", "migrate", "sync"], ["asset"]]
      end

      def self.manager
        require "iam/manager/Manager"
        Cumulus::IAM::Manager.new
      end

      def self.execute
        resource = super

        if ARGV[2] == "diff" and ARGV.size == 4
          resource.diff_one(ARGV[3])
        elsif ARGV[2] == "sync" and ARGV.size == 4
          resource.sync_one(ARGV[3])
        else
          resource.method(ARGV[2]).call
        end
      end

    end
  end
end
