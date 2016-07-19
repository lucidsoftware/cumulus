module Cumulus
  module EC2
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.command_details
        format_message([
          "ebs - Manage EBS volumes in groups",
          ["diff", "get a list of groups that have different definitions locally than in AWS (supplying the name of the group will diff only that group)"],
          ["list", "list the groups defined in configuration"],
          ["migrate", "create group configuration files that match the definitions in AWS"],
          ["sync", "sync the local group definition with AWS (supplying the name of the group will sync only that group). Also creates volumes in a group"],
          "instances - Manage EC2 instances",
          ["diff", "get a list of instances that have different definitions locally than in AWS (supplying the name of the instance will diff only that instance)"],
          ["list", "list the instances defined in configuration"],
          ["migrate", "create instances configuration files that match the definitions in AWS"],
          ["sync", "sync the local instance definition with AWS (supplying the name of the instance will sync only that instance)"],
        ], indent: 1)
      end

      def self.manager_name
        "ec2"
      end

      def self.valid_options
         [["ebs", "instances"], ["diff", "list", "migrate", "sync"]]
      end

      def self.execute(arguments)
        manager = if arguments[0] == "ebs"
          require "ec2/managers/EbsManager"
          Cumulus::EC2::EbsManager.new
        elsif arguments[0] == "instances"
          require "ec2/managers/InstanceManager"
          Cumulus::EC2::InstanceManager.new
        else
          nil
        end

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
