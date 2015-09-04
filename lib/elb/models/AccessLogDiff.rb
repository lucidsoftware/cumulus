require "common/models/Diff"
require "util/Colors"

module Cumulus
  module ELB
    # Public: The types of changes that can be made to an access log config
    module AccessLogChange
      include Common::DiffChange

      ENABLED = Common::DiffChange.next_change_id
      BUCKET = Common::DiffChange.next_change_id
      EMIT = Common::DiffChange.next_change_id
      PREFIX = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and
    # an AWS Load Balancer Access Log.
    class AccessLogDiff < Common::Diff
      include AccessLogChange

      def asset_type
        "Access Log Config"
      end

      def diff_string
        case @type
        when ENABLED
          [
            "enabled:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when BUCKET
          [
            "S3 bucket:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when EMIT
          [
            "emit interval:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when PREFIX
          [
            "bucket prefix:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        end
      end
    end
  end
end
