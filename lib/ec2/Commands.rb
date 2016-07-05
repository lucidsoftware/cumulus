module Cumulus
  module EC2
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        "ec2: Manage EC2 instances and related configuration."
      end

      def self.usage_message
        "Usage: cumulus ec2 [help|ebs|instances] [diff|list|migrate|sync] [asset]"
      end

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
        if ARGV[1] == "ebs"
          Cumulus::EC2::EbsManager.new
        elsif ARGV[1] == "instances"
          Cumulus::EC2::InstanceManager.new
        else
          nil
        end
      end

      def self.valid_options
         [["ebs", "instances"], ["diff", "list", "migrate", "sync"], ["asset"]]
      end

      def self.execute
        if ARGV[2] == "diff" and ARGV.size == 4
          manager.diff_one(ARGV[3])
        elsif ARGV[2] == "sync" and ARGV.size == 4
          manager.sync_one(ARGV[3])
        else
          manager.method(ARGV[2]).call
        end
      end

    end
  end
end
