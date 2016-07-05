module Cumulus
  module ELB
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.command_details
        [
          "\tdiff\t- print out differences between local configuration and AWS (supplying the name of the elb will diff only that elb)",
          "\tlist\t- list the locally defined ELBs",
          "\tsync\t- sync local ELB definitions with AWS (supplying the name of the elb will sync only that elb)",
          "\tmigrate\t- migrate AWS configuration to Cumulus",
          "\t\tdefault-policies- migrate default ELB policies from AWS to Cumulus",
          "\t\telbs\t\t- migrate the current ELB configuration from AWS to Cumulus",
        ].join("\n")
      end

      def self.manager
        require "elb/manager/Manager"
        Cumulus::ELB::Manager.new
      end

      def self.execute
        if ARGV[1] == "migrate"
          if ARGV[2] == "default-policies"
            manager.migrate_default_policies
          elsif ARGV[2] == "elbs"
            manager.migrate_elbs
          else
            puts "Usage: cumulus elb migrate [default-policies|elbs]"
          end
        else
          super
        end
      end

    end
  end
end
