require "common/models/Diff"
require "vpc/models/RouteDiff"
require "util/Colors"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to a route
    module RouteChange
      include Common::DiffChange

      GATEWAY = Common::DiffChange.next_change_id
      INSTANCE = Common::DiffChange.next_change_id
      NETWORK = Common::DiffChange.next_change_id
      VPC_PEERING = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration AWS configuration
    class RouteDiff < Common::Diff
      include RouteChange

      def asset_type
        "Route"
      end

      def aws_name
        @aws.destination_cidr_block
      end

      def diff_string
        resource = case @type
        when GATEWAY
          "Gateway"
        when INSTANCE
          "Instance"
        when NETWORK
          "Network Interface"
        when VPC_PEERING
          "VPC Peering Connection"
        end

        [
          "#{resource}:",
          Colors.aws_changes("\tAWS - #{aws}"),
          Colors.local_changes("\tLocal - #{local}"),
        ].join("\n")

      end
    end
  end
end
