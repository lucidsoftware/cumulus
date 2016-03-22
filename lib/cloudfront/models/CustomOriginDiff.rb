require "common/models/Diff"
require "util/Colors"

module Cumulus
  module CloudFront

  	# Public: The types of changes that can be made to zones
    module CustomOriginChange
      include Common::DiffChange

      HTTP = Common::DiffChange::next_change_id
      HTTPS = Common::DiffChange::next_change_id
      POLICY = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of zones.
    class CustomOriginDiff < Common::Diff
      include CustomOriginChange

      def diff_string
        case @type
        when HTTP
          [
            "http port:",
            Colors.aws_changes("\tAWS - #{@aws}"),
            Colors.local_changes("\tLocal - #{@local}"),
          ].join("\n")
        when HTTPS
          [
            "https port:",
            Colors.aws_changes("\tAWS - #{@aws}"),
            Colors.local_changes("\tLocal - #{@local}"),
          ].join("\n")
        when POLICY
          [
            "protocol policy:",
            Colors.aws_changes("\tAWS - #{@aws}"),
            Colors.local_changes("\tLocal - #{@local}"),
          ].join("\n")
        end
      end

      def aws_name
        @aws.id
      end

    end

  end
end
