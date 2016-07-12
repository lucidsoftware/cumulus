module Cumulus
  module ELB
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.command_details
        format_message [
          ["diff", "print out differences between local configuration and AWS (supplying the name of the elb will diff only that elb)"],
          ["list", "list the locally defined ELBs"],
          ["sync", "sync local ELB definitions with AWS (supplying the name of the elb will sync only that elb)"],
          ["migrate", "migrate AWS configuration to Cumulus"],
          format_message([
            ["default-policies", "migrate default ELB policies from AWS to Cumulus"],
            ["elbs", "migrate the current ELB configuration from AWS to Cumulus"],
          ], indent: 1),
        ]
      end

      def self.manager
        require "elb/manager/Manager"
        Cumulus::ELB::Manager.new
      end

      def self.execute(arguments)
        if arguments[0] == "migrate"
          if arguments[1] == "default-policies"
            manager.migrate_default_policies
          elsif arguments[1] == "elbs"
            manager.migrate_elbs
          else
            puts "Usage: cumulus elb migrate [default-policies|elbs]"
          end
        else
          super(arguments)
        end
      end

    end
  end
end
