module Cumulus
  module CloudFront
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        format_message [
          "cloudfront: Manage CloudFront",
          "\tDiff and sync CloudFront configuration with AWS.",
        ]
      end

      def self.command_details
        format_message [
          ["diff", "print out differences between local configuration and AWS (supplying the id of the distribution will diff only that distribution)"],
          ["invalidate", "create an invalidation.  Must supply the name of the invalidation to run.  Specifying 'list' as an argument lists the local invalidation configurations"],
          ["list", "list the locally defined distributions"],
          ["migrate", "produce Cumulus CloudFront distribution configuration from current AWS configuration"],
          ["sync", "sync local cloudfront distribution configuration with AWS (supplying the id of the distribution will sync only that distribution)"],
        ]
      end

      def self.manager
        require "cloudfront/manager/Manager"
        Cumulus::CloudFront::Manager.new
      end

      def self.valid_options
        [["diff", "invalidate", "list", "migrate", "sync"]]
      end

      def self.execute(arguments)
        if arguments[0] == "invalidate"
          if arguments.size != 2
            puts "Specify one invalidation to run"
            exit
          else
            if arguments[1] == "list"
              manager.list_invalidations
            else
              manager.invalidate(arguments[1])
            end
          end
        else
          super(arguments)
        end
      end

    end
  end
end
