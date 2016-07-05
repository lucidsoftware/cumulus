module Cumulus
  module CloudFront
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        [
          "cloudfront: Manage CloudFront",
          "\tDiff and sync CloudFront configuration with AWS.",
        ].join("\n")
      end

      def self.command_details
        [
          "\tdiff\t\t- print out differences between local configuration and AWS (supplying the id of the distribution will diff only that distribution)",
          "\tinvalidate\t- create an invalidation.  Must supply the name of the invalidation to run.  Specifying 'list' as an argument lists the local invalidation configurations",
          "\tlist\t\t- list the locally defined distributions",
          "\tmigrate\t\t- produce Cumulus CloudFront distribution configuration from current AWS configuration",
          "\tsync\t\t- sync local cloudfront distribution configuration with AWS (supplying the id of the distribution will sync only that distribution)",
        ].join("\n")
      end

      def self.manager
        require "cloudfront/manager/Manager"
        Cumulus::CloudFront::Manager.new
      end

      def self.valid_options
        [["diff", "invalidate", "list", "migrate", "sync"], ["asset"]]
      end

      def self.execute
        if ARGV[1] == "invalidate"
          if ARGV.size != 3
            puts "Specify one invalidation to run"
            exit
          else
            if ARGV[2] == "list"
              manager.list_invalidations
            else
              manager.invalidate(ARGV[2])
            end
          end
        else
          super
        end
      end

    end
  end
end
