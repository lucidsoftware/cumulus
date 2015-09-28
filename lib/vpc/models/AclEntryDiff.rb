require "common/models/Diff"
require "util/Colors"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to an acl entry
    module AclEntryChange
      include Common::DiffChange

      PROTOCOL = Common::DiffChange.next_change_id
      ACTION = Common::DiffChange.next_change_id
      CIDR = Common::DiffChange.next_change_id
      PORTS = Common::DiffChange.next_change_id
      ICMP_TYPE = Common::DiffChange.next_change_id
      ICMP_CODE = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class AclEntryDiff < Common::Diff
      include AclEntryChange

      def asset_type
        "Network Acl Entry"
      end

      def aws_name
        @aws.rule_number
      end

      def diff_string
        resource = case @type
        when PROTOCOL
          "Protocol"
        when ACTION
          "Action"
        when CIDR
          "CIDR Block"
        when PORTS
          "Ports"
        when ICMP_TYPE
          "ICMP Type"
        when ICMP_CODE
          "ICMP Code"
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
