require "common/models/Diff"
require "util/Colors"

module Cumulus
  module S3
    # Public: The types of changes that cna be made to an S3 Lifecycle Rule
    module LifecycleChange
      include Common::DiffChange

      DAYS_UNTIL_DELETE = Common::DiffChange.next_change_id
      DAYS_UNTIL_GLACIER = Common::DiffChange.next_change_id
      PAST_UNTIL_DELETE = Common::DiffChange.next_change_id
      PAST_UNTIL_GLACIER = Common::DiffChange.next_change_id
      PREFIX = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # lifecycle rule configuration
    class LifecycleDiff < Common::Diff
      include LifecycleChange

      def asset_type
        "Lifecycle rule"
      end

      def aws_name
        @aws.name
      end

      def diff_string
        case @type
        when DAYS_UNTIL_DELETE
          "Days before objects are deleted: AWS - #{Colors.aws_changes(@aws.days_until_delete)}, Local - #{Colors.local_changes(@local.days_until_delete)}"
        when DAYS_UNTIL_GLACIER
          "Days before transition to Glacier: AWS - #{Colors.aws_changes(@aws.days_until_glacier)}, Local - #{Colors.local_changes(@local.days_until_glacier)}"
        when PAST_UNTIL_DELETE
          "Days before past version objects are deleted: AWS - #{Colors.aws_changes(@aws.past_days_until_delete)}, Local - #{Colors.local_changes(@local.past_days_until_delete)}"
        when PAST_UNTIL_GLACIER
          "Days before past version transition to Glacier: AWS - #{Colors.aws_changes(@aws.past_days_until_glacier)}, Local - #{Colors.local_changes(@local.past_days_until_glacier)}"
        when PREFIX
          "Prefix - AWS #{Colors.aws_changes(@aws.prefix)}, Local - #{Colors.local_changes(@local.prefix)}"
        end
      end
    end
  end
end
