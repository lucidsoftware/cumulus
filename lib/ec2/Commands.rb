module Cumulus
  module EC2
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.command_details
        [
          "\tebs - Manage EBS volumes in groups",
          "\t\tdiff\t- get a list of groups that have different definitions locally than in AWS (supplying the name of the group will diff only that group)",
          "\t\tlist\t- list the groups defined in configuration",
          "\t\tmigrate\t- create group configuration files that match the definitions in AWS",
          "\t\tsync\t- sync the local group definition with AWS (supplying the name of the group will sync only that group). Also creates volumes in a group",
          "\tinstances - Manage EC2 instances",
          "\t\tdiff\t- get a list of instances that have different definitions locally than in AWS (supplying the name of the instance will diff only that instance)",
          "\t\tlist\t- list the instances defined in configuration",
          "\t\tmigrate\t - create instances configuration files that match the definitions in AWS",
          "\t\tsync\t- sync the local instance definition with AWS (supplying the name of the instance will sync only that instance)",
        ].join("\n")
      end

      def self.manager
        require "ec2/managers/EbsManager"
        require "ec2/managers/InstanceManager"
        if arguments[1] == "ebs"
          Cumulus::EC2::EbsManager.new
        elsif arguments[1] == "instances"
          Cumulus::EC2::InstanceManager.new
        else
          nil
        end
      end

      def self.manager_name
        "ec2"
      end

      def self.valid_options
         [["ebs", "instances"], ["diff", "list", "migrate", "sync"]]
      end

      def self.execute(arguments)
        if arguments[1] == "diff" and arguments.size == 3
          manager.diff_one(arguments[2])
        elsif arguments[1] == "sync" and arguments.size == 3
          manager.sync_one(arguments[2])
        else
          manager.method(arguments[1]).call
        end
      end

    end
  end
end
