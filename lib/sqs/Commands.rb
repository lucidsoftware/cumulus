module Cumulus
  module SQS
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        format_message [
          "SQS: Manage SQS",
          "\tDiff and sync SQS configuration with AWS.",
        ]
      end

      def self.command_details
        format_message [
          ["diff", "print out differences between local configuration and AWS (supplying the name of the queue will diff only that queue)"],
          ["list", "list the locally defined queues"],
          ["urls", "list the url for each locally defined queue"],
          ["sync", "sync local queue definitions with AWS (supplying the name of the queue will sync only that queue)"],
          ["migrate", "migrate AWS configuration to Cumulus"],
        ]
      end

      def self.manager
        require "sqs/manager/Manager"
        Cumulus::SQS::Manager.new
      end

      def self.valid_options
        [["diff", "list", "migrate", "sync", "urls"]]
      end

    end
  end
end
