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

      def diff_string
        case @type
        when TARGET
          [
            "target:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when INTERVAL
          [
            "interval:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when TIMEOUT
          [
            "timeout:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when HEALTHY
          [
            "healthy threshold:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when UNHEALTHY
          [
            "unhealthy threshold:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        end
      end
    end
  end
end
