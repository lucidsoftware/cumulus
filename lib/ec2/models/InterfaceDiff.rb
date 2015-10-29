require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

require 'json'

module Cumulus
  module EC2
    # Public: The types of changes that can be made to an EBS volume group
    module InterfaceChange
      include Common::DiffChange

      SUBNET = Common::DiffChange.next_change_id
      GROUPS = Common::DiffChange.next_change_id
      DESCRIPTION = Common::DiffChange.next_change_id
      SDCHECK = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class InterfaceDiff < Common::Diff
      include InterfaceChange

      def self.groups(aws, local)
        changes = Common::ListChange.simple_list_diff(aws, local)
        InterfaceDiff.new(GROUPS, aws, local, changes)
      end

      def asset_type
        "Network Interface"
      end

      def aws_name
        @name
      end

      def diff_string
        case @type
        when SUBNET
          [
            "Subnet:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when GROUPS
          [
            "Security Groups:",
            @changes.removed.map { |sg| Colors.unmanaged("\t#{sg}") },
            @changes.added.map { |sg| Colors.added("\t#{sg}") },
          ].join("\n")
        when DESCRIPTION
          [
            "Description:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when SDCHECK
          [
            "Source Dest Check:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        end
      end
    end
  end
end
