require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

module Cumulus
  module S3
    # Public: The types of changes that can be made to an S3 Notification
    module NotificationChange
      include Common::DiffChange

      PREFIX = Common::DiffChange.next_change_id
      SUFFIX = Common::DiffChange.next_change_id
      TRIGGERS = Common::DiffChange.next_change_id
      TYPE = Common::DiffChange.next_change_id
      TARGET = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # S3 Notification configuration
    class NotificationDiff < Common::Diff
      include NotificationChange

      def initialize(type, aws = nil, local = nil)
        super(type, aws, local)

        if aws and local
          @triggers = Common::ListChange.new(
            local.triggers - aws.triggers,
            aws.triggers - local.triggers
          )
        end
      end

      def asset_type
        "Notification"
      end

      def aws_name
        @aws.name
      end

      def diff_string
        case @type
        when PREFIX
          "Prefix: AWS - #{Colors.aws_changes(@aws.prefix)}, Local - #{Colors.local_changes(@local.prefix)}"
        when SUFFIX
          "Suffix: AWS - #{Colors.aws_changes(@aws.suffix)}, Local - #{Colors.local_changes(@local.suffix)}"
        when TRIGGERS
          [
            "Triggers:",
            @triggers.removed.map { |t| Colors.removed("\t#{t}") },
            @triggers.added.map { |t| Colors.added("\t#{t}") },
          ].flatten.join("\n")
        when TYPE
          "Type: AWS - #{Colors.aws_changes(@aws.type)}, Local - #{Colors.local_changes(@local.type)}"
        when TARGET
          "Target: AWS - #{Colors.aws_changes(@aws.target)}, Local - #{Colors.local_changes(@local.target)}"
        end
      end
    end
  end
end
