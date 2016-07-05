module Cumulus
  module SQS
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        [
          "SQS: Manage SQS",
          "\tDiff and sync SQS configuration with AWS.",
        ].join("\n")
      end

      def self.command_details
        [
          "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the queue will diff only that queue)",
          "\tlist\t- list the locally defined queues",
          "\turls\t- list the url for each locally defined queue",
          "\tsync\t- sync local queue definitions with AWS (supplying the name of the queue will sync only that queue)",
          "\tmigrate\t- migrate AWS configuration to Cumulus",
        ].join("\n")
      end

      def self.manager
        require "sqs/manager/Manager"
        Cumulus::SQS::Manager.new
      end

      def self.valid_options
        [["diff", "list", "migrate", "sync", "urls"], ["asset"]]
      end

    end
  end
end
