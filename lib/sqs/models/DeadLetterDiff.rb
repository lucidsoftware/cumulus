require "common/models/Diff"
require "util/Colors"

module Cumulus
  module SQS
    # Public: The types of changes that can be made to a dead letter config
    module DeadLetterChange
      include Common::DiffChange

      TARGET = Common::DiffChange.next_change_id
      RECEIVE = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class DeadLetterDiff < Common::Diff
      include DeadLetterChange

      def diff_string
        asset = case @type
        when TARGET
          "Target"
        when RECEIVE
          "Max Receive Count"
        end

        [
          "#{asset}:",
          Colors.aws_changes("\tAWS - #{aws}"),
          Colors.local_changes("\tLocal - #{local}")
        ].join("\n")

      end
    end
  end
end
