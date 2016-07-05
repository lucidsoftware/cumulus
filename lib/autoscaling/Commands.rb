module Cumulus
  module AutoScaling
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        [
          "autoscaling: Manage AutoScaling groups.",
          "\tCompiles AutoScaling groups, scaling policies, and alarms that are defined in configuration files and syncs the resulting AutoScaling groups with AWS.",
        ].join("\n")
      end

      def self.manager
        require "autoscaling/manager/Manager"
        Cumulus::AutoScaling::Manager.new
      end

    end
  end
end
