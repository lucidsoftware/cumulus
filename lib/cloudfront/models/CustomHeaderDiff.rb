require "common/models/Diff"
require 'util/Colors'

module Cumulus
  module CloudFront
    module CustomHeaderChange
      include Common::DiffChange

      NAME = Common::DiffChange::next_change_id
      VALUE = Common::DiffChange::next_change_id
    end

    class CustomHeaderDiff < Common::Diff
      include CustomHeaderChange

      def diff_string
        case @type
        when NAME
          [
            "name:",
            Colors.aws_changes("\tAWS - #{@aws.name}"),
            Colors.local_changes("\tLocal - #{@local.name}")
          ].join("\n")
        when VALUE
          [
            "value:",
            Colors.aws_changes("\tAWS - #{@aws.value}"),
            Colors.local_changes("\tLocal - #{@local.value}")
          ].join("\n")
        end
      end

      def asset_type
        "Custom Origin Header"
      end

      def aws_name
        @aws.name
      end

      def local_name
        @local.name
      end
    end
  end
end
