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
            Colors.aws_changes("\tAWS - #{@aws.http_port}"),
            Colors.local_changes("\tLocal - #{@local.http_port}"),
          ].join("\n")
        when HTTPS
          [
            "https port:",
            Colors.aws_changes("\tAWS - #{@aws.https_port}"),
            Colors.local_changes("\tLocal - #{@local.https_port}"),
          ].join("\n")
        when POLICY
          [
            "protocol policy:",
            Colors.aws_changes("\tAWS - #{@aws.origin_protocol_policy}"),
            Colors.local_changes("\tLocal - #{@local.protocol_policy}"),
          ].join("\n")
        end
      end

      def aws_name
        @aws.id
      end

    end

  end
end
