module Cumulus
  module VPC
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.command_details
        format_message [
          ["diff", "print out differences between local configuration and AWS (supplying the name of the VPC will diff only that VPC)"],
          ["list", "list the locally defined VPCs"],
          ["sync", "sync local VPC definitions with AWS (supplying the name of the VPC will sync only that VPC)"],
          ["migrate", "migrate AWS configuration to Cumulus"],
          ["rename", "renames a cumulus asset and all references to it"],
        ]
      end

      def self.manager
        require "vpc/manager/Manager"
        Cumulus::VPC::Manager.new
      end

      def self.valid_options
        [["diff", "list", "migrate", "sync", "rename"]]
      end

      def self.execute(arguments)
        if arguments[0] == "diff" and arguments.size == 2
          manager.diff_one(arguments[1])
        elsif arguments[0] == "sync" and arguments.size == 2
          manager.sync_one(arguments[1])
        elsif arguments[0] == "rename"
          if arguments.size == 5
            manager.rename(arguments[1], arguments[2], arguments[3])
          else
            puts "Usage: cumulus vpc rename [network-acl|policy|route-table|subnet|vpc] <old-asset-name> <new-asset-name>"
          end
        else
          manager.method(arguments[0]).call
        end
      end

    end
  end
end
