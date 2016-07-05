module Cumulus
  module Kinesis
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        [
          "kinesis: Manage Kinesis Streams",
          "\tDiff and sync Kinesis configuration with AWS.",
        ].join("\n")
      end

      def self.command_details
        [
          "\tdiff\t- get a list of resources that have different definitions locally than in AWS (supplying the name of the group will diff only that group)",
          "\tlist\t- list the resources defined in configuration",
          "\tmigrate\t- create resource configuration files that match the definitions in AWS",
          "\tsync\t- sync the local resource definition with AWS (supplying the name of the resource will sync only that group). Also adds and removes users from groups",
        ].join("\n")
      end

      def self.manager
        require "kinesis/manager/Manager"
        Cumulus::Kinesis::Manager.new
      end

    end
  end
end
