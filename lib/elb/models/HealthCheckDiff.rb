require "common/models/Diff"
require "util/Colors"

module Cumulus
  module ELB
    # Public: The types of changes that can be made to an access log config
    module HealthCheckChange
      include Common::DiffChange

      TARGET = Common::DiffChange.next_change_id
      INTERVAL = Common::DiffChange.next_change_id
      TIMEOUT = Common::DiffChange.next_change_id
      HEALTHY = Common::DiffChange.next_change_id
      UNHEALTHY = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and
    # an AWS Load Balancer Health Check
    class HealthCheckDiff < Common::Diff
      include HealthCheckChange

      def asset_type
        "Health Check Config"
      end

      def change_string
        case @type
        when TARGET
          "target:"
        when INTERVAL
          "interval:"
        when TIMEOUT
          "timeout:"
        when HEALTHY
          "healthy threshold:"
        when UNHEALTHY
          "unhealthy threshold:"
        end
      end

      def diff_string
        [
          change_string,
          Colors.aws_changes("\tAWS - #{aws}"),
          Colors.local_changes("\tLocal - #{local}"),
        ].join("\n")
      end
    end
  end
end
