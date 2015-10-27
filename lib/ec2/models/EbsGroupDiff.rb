require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

require 'json'

module Cumulus
  module EC2
    # Public: The types of changes that can be made to an EBS volume group
    module EbsGroupChange
      include Common::DiffChange

      AZ = Common::DiffChange.next_change_id
      VG_ADDED = Common::DiffChange.next_change_id
      VG_REMOVED = Common::DiffChange.next_change_id
      VG_COUNT = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class EbsGroupDiff < Common::Diff
      include EbsGroupChange

      def asset_type
        "EBS Volume Group"
      end

      def aws_name
        @name
      end

      def diff_string
        case @type
        when AZ
          [
            "Availability Zone:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].flatten.join("\n")
        when VG_ADDED
          Colors.added("Volume Group Added: #{local.count} x #{local.description}")
        when VG_REMOVED
          Colors.unmanaged("Volume Group Unmanaged: #{aws.count} x #{aws.description}")
        when VG_COUNT
          Colors.local_changes("Count changed from #{aws.count} to #{local.count}: #{local.description}")
        end
      end
    end
  end
end
