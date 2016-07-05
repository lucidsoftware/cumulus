module Cumulus
  module VPC
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.command_details
        [
          "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the VPC will diff only that VPC)",
          "\tlist\t- list the locally defined VPCs",
          "\tsync\t- sync local VPC definitions with AWS (supplying the name of the VPC will sync only that VPC)",
          "\tmigrate\t- migrate AWS configuration to Cumulus",
          "\trename\t- renames a cumulus asset and all references to it",
        ].join("\n")
      end

      def self.manager
        require "vpc/manager/Manager"
        Cumulus::VPC::Manager.new
      end

      def self.valid_options
        [["diff", "list", "migrate", "sync", "rename"], ["asset"]]
      end

      def self.execute
        if ARGV[1] == "diff" and ARGV.size != 2
          manager.diff_one(ARGV[2])
        elsif ARGV[1] == "sync" and ARGV.size != 2
          manager.sync_one(ARGV[2])
        elsif ARGV[1] == "rename"
          if ARGV.size == 5
            manager.rename(ARGV[2], ARGV[3], ARGV[4])
          else
            puts "Usage: cumulus vpc rename [network-acl|policy|route-table|subnet|vpc] <old-asset-name> <new-asset-name>"
          end
        else
          manager.method(ARGV[1]).call
        end
      end

    end
  end
end
