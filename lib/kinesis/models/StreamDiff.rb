require "common/models/Diff"
require "common/models/ListChange"
require "common/models/TagsDiff"
require "util/Colors"

module Cumulus
  module Kinesis
    # Public: The types of changes that can be made to a stream
    module StreamChange
      include Common::DiffChange

      SHARDS = Common::DiffChange.next_change_id
      RETENTION = Common::DiffChange.next_change_id
      TAGS = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class StreamDiff < Common::Diff
      include StreamChange
      include Common::TagsDiff

      def local_tags
        @local
      end

      def aws_tags
        @aws
      end

      def asset_type
        "Stream"
      end

      def aws_name
        @aws.stream_name
      end

      def diff_string
        case @type
        when SHARDS
          [
            "Shards:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when RETENTION
          [
            "Retention:",
            Colors.aws_changes("\tAWS - #{aws} hours"),
            Colors.local_changes("\tLocal - #{local} hours"),
          ].join("\n")
        when TAGS
          tags_diff_string
        end
      end
    end
  end
end
