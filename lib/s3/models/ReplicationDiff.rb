require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

module Cumulus
  module S3
    # Public: The types of changes that can be made to S3 Replication
    module ReplicationChange
      include Common::DiffChange

      DESTINATION = Common::DiffChange.next_change_id
      PREFIX = Common::DiffChange.next_change_id
      ROLE = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # S3 Replication configuration.
    class ReplicationDiff < Common::Diff
      include ReplicationChange

      def initialize(type, aws = nil, local = nil)
        super(type, aws, local)

        if aws and local
          @prefixes = Common::ListChange.new(
            local.prefixes - aws.prefixes,
            aws.prefixes - local.prefixes
          )
        end
      end

      def asset_type
        "S3 Replication"
      end

      def aws_name
        "Configuration"
      end

      def local_name
        "Configuration"
      end

      def diff_string
        case @type
        when DESTINATION
          "Destination: AWS - #{Colors.aws_changes(@aws.destination)}, Local - #{Colors.local_changes(@local.destination)}"
        when ROLE
          "IAM Role: AWS - #{Colors.aws_changes(@aws.iam_role)}, Local - #{Colors.local_changes(@local.iam_role)}"
        when PREFIX
          [
            "Prefixes:",
            @prefixes.removed.map { |p| Colors.removed("\t#{p}") },
            @prefixes.added.map { |p| Colors.added("\t#{p}") },
          ].flatten.join("\n")
        end
      end
    end
  end
end
