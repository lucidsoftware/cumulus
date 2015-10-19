require "common/models/Diff"
require "util/Colors"

module Cumulus
  module SQS
    # Public: The types of changes that can be made to a dead letter config
    module QueueChange
      include Common::DiffChange

      DELAY = Common::DiffChange.next_change_id
      MESSAGE_SIZE = Common::DiffChange.next_change_id
      MESSAGE_RETENTION = Common::DiffChange.next_change_id
      RECEIVE_WAIT = Common::DiffChange.next_change_id
      VISIBILITY = Common::DiffChange.next_change_id
      DEAD = Common::DiffChange.next_change_id
      POLICY = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class QueueDiff < Common::Diff
      include QueueChange

      def asset_type
        "Queue"
      end

      def aws_name
        @aws.name
      end

      def diff_string
        case @type
        when DELAY
          [
            "Delay",
            Colors.aws_changes("\tAWS - #{aws} seconds"),
            Colors.local_changes("\tLocal - #{local} seconds")
          ].join("\n")
        when MESSAGE_SIZE
          [
            "Max Message Size",
            Colors.aws_changes("\tAWS - #{aws} bytes"),
            Colors.local_changes("\tLocal - #{local} bytes")
          ].join("\n")
        when MESSAGE_RETENTION
          [
            "Message Retention Period",
            Colors.aws_changes("\tAWS - #{aws} seconds"),
            Colors.local_changes("\tLocal - #{local} seconds")
          ].join("\n")
        when RECEIVE_WAIT
          [
            "Receive Wait Time",
            Colors.aws_changes("\tAWS - #{aws} seconds"),
            Colors.local_changes("\tLocal - #{local} seconds")
          ].join("\n")
        when VISIBILITY
          [
            "Message Visibility",
            Colors.aws_changes("\tAWS - #{aws} seconds"),
            Colors.local_changes("\tLocal - #{local} seconds")
          ].join("\n")
        when DEAD
          [
            "Dead Letter Queue",
            @changes.join("\n").lines.map { |l| "\t#{l}".chomp("\n") }
          ].flatten.join("\n")
        when POLICY
          [
            "Policy:",
            if aws
              Colors.unmanaged([
                "\tRemoving:",
                JSON.pretty_generate(aws).lines.map { |l| "\t\t#{l}".chomp("\n") }
              ].join("\n"))
            end,
            if local
              Colors.added([
                "\tAdding:",
                JSON.pretty_generate(local).lines.map { |l| "\t\t#{l}".chomp("\n") }
              ].join("\n"))
            end
          ].reject(&:nil?).join("\n")
        end
      end

    end
  end
end
