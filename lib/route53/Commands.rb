module Cumulus
  module Route53
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        [
          "route53: Manage Route53",
          "\tDiff and sync Route53 configuration with AWS.",
        ].join("\n")
      end

      def self.manager
        require "route53/manager/Manager"
        Cumulus::Route53::Manager.new
      end

    end
  end
end
