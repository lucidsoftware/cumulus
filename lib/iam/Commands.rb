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
        [["groups", "roles", "users"], ["diff", "list", "migrate", "sync"]]
      end

      def self.manager
        require "iam/manager/Manager"
        Cumulus::IAM::Manager.new
      end

      def self.execute(arguments)
        resource = super(arguments)

        if arguments[1] == "diff" and arguments.size == 3
          resource.diff_one(arguments[2])
        elsif arguments[1] == "sync" and arguments.size == 3
          resource.sync_one(arguments[2])
        else
          resource.method(arguments[1]).call
        end
      end

    end
  end
end
