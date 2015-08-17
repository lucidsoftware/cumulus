require "common/models/Diff"
require "util/Colors"

module Cumulus
  module AutoScaling
    # Public: The types of changes that can be made to scaling policies
    module PolicyChange
      include Common::DiffChange

      ADJUSTMENT = Common::DiffChange::next_change_id
      ADJUSTMENT_TYPE = Common::DiffChange::next_change_id
      ALARM = Common::DiffChange::next_change_id
      COOLDOWN = Common::DiffChange::next_change_id
      MIN_ADJUSTMENT = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of scaling policies
    class PolicyDiff < Common::Diff
      include PolicyChange

      attr_accessor :alarm_diffs
      attr_accessor :policy_arn

      # Public: Static method that will produce a diff that contains changes in
      # cloudwatch alarms
      #
      # alarm_diffs - the differences in alarms
      # local       - the local configuration for the change
      # policy_arn  - the arn of the policy the alarms should be associated with
      #
      # Returns the diff
      def self.alarms(alarm_diffs, local, policy_arn)
        diff = PolicyDiff.new(ALARM, nil, local)
        diff.alarm_diffs = alarm_diffs
        diff.policy_arn = policy_arn
        diff
      end

      def diff_string
        diff_lines = [@local.name]

        case @type
        when ADJUSTMENT_TYPE
          diff_lines << "\tAdjustment type: AWS - #{Colors.aws_changes(@aws.adjustment_type)}, Local - #{Colors.local_changes(@local.adjustment_type)}"
        when ADJUSTMENT
          diff_lines << "\tScaling adjustment: AWS - #{Colors.aws_changes(@aws.scaling_adjustment)}, Local - #{Colors.local_changes(@local.adjustment)}"
        when ALARM
          lines = ["\t\tCloudwatch alarms:"]
          lines << alarm_diffs.map do |diff|
            diff.to_s.lines.map {|s| "\t\t\t#{s}" }.join
          end
          diff_lines << lines.flatten.join("\n")
        when COOLDOWN
          diff_lines << "\tCooldown: AWS - #{Colors.aws_changes(@aws.cooldown)}, Local - #{Colors.local_changes(@local.cooldown)}"
        when MIN_ADJUSTMENT
          diff_lines << "\tMin adjustment step: AWS - #{Colors.aws_changes(@aws.min_adjustment_step)}, Local - #{Colors.local_changes(@local.min_adjustment)}"
        end

        diff_lines.flatten.join("\n")
      end

      def asset_type
        "Scaling policy"
      end

      def aws_name
        @aws.policy_name
      end

    end
  end
end
