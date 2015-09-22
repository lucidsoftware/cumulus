require "common/models/Diff"
require "common/models/TagsDiff"
require "util/Colors"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to a subnet
    module SubnetChange
      include Common::DiffChange

      CIDR = Common::DiffChange.next_change_id
      PUBLIC = Common::DiffChange.next_change_id
      ROUTE = Common::DiffChange.next_change_id
      NETWORK = Common::DiffChange.next_change_id
      AZ = Common::DiffChange.next_change_id
      TAGS = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class SubnetDiff < Common::Diff
      include SubnetChange
      include Common::TagsDiff

      def local_tags
        @local
      end

      def aws_tags
        @aws
      end

      def asset_type
        "Subnet"
      end

      def aws_name
        @aws.name
      end

      def diff_string
        case @type
        when CIDR
          [
            "CIDR Block:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when PUBLIC
          [
            "Map Public Ip:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when ROUTE
          [
            "Route Table:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when NETWORK
          [
            "Network ACL:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when AZ
          [
            "Availability Zone:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when TAGS
          tags_diff_string
        end
      end
    end
  end
end
