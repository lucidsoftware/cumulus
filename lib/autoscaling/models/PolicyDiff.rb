require "common/models/Diff"
require "util/Colors"

# Public: The types of changes that can be made to scaling policies
module PolicyChange
  include DiffChange

  ADJUSTMENT = DiffChange::next_change_id
  ADJUSTMENT_TYPE = DiffChange::next_change_id
  ALARM = DiffChange::next_change_id
  COOLDOWN = DiffChange::next_change_id
  MIN_ADJUSTMENT = DiffChange::next_change_id
end

# Public: Represents a single difference between local configuration and AWS
# configuration of scaling policies
class PolicyDiff < Diff
  include PolicyChange

  attr_accessor :alarm_diffs

  # Public: Static method that will produce a diff that contains changes in
  # cloudwatch alarms
  #
  # alarm_diffs - the differences in alarms
  #
  # Returns the diff
  def self.alarms(alarm_diffs)
    diff = PolicyDiff.new(ALARM)
    diff.alarm_diffs = alarm_diffs
    diff
  end

  def diff_string
    case @type
    when ADJUSTMENT_TYPE
      "Adjustment type: AWS - #{Colors.aws_changes(@aws.adjustment_type)}, Local - #{Colors.local_changes(@local.adjustment_type)}"
    when ADJUSTMENT
      "Scaling adjustment: AWS - #{Colors.aws_changes(@aws.scaling_adjustment)}, Local - #{Colors.local_changes(@local.adjustment)}"
    when ALARM
      lines = ["Cloudwatch alarms:"]
      lines << alarm_diffs.map do |diff|
        diff.to_s.lines.map {|s| "\t\t#{s}" }.join
      end
      lines.flatten.join("\n")
    when COOLDOWN
      "Cooldown: AWS - #{Colors.aws_changes(@aws.cooldown)}, Local - #{Colors.local_changes(@local.cooldown)}"
    when MIN_ADJUSTMENT
      "Min adjustment step: AWS - #{Colors.aws_chnages(@aws.min_adjustment_step)}, Local - #{Colors.local_changes(@local.min_adjustment)}"
    end
  end

  def asset_type
    "Scaling policy"
  end

  def aws_name
    @aws.policy_name
  end

end
