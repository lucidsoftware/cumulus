require "common/models/Diff"
require "util/Colors"

# Public: The types of changes that can be made to alarms
module AlarmChange
  include DiffChange

  ALARM = DiffChange::next_change_id
  COMPARISON = DiffChange::next_change_id
  DESCRIPTION = DiffChange::next_change_id
  DIMENSIONS = DiffChange::next_change_id
  ENABLED = DiffChange::next_change_id
  EVALUATION = DiffChange::next_change_id
  INSUFFICIENT = DiffChange::next_change_id
  METRIC = DiffChange::next_change_id
  NAMESPACE = DiffChange::next_change_id
  OK = DiffChange::next_change_id
  PERIOD = DiffChange::next_change_id
  STATISTIC = DiffChange::next_change_id
  THRESHOLD = DiffChange::next_change_id
  UNIT = DiffChange::next_change_id
end

# Public: Represents a single difference between local configuration and AWS
# configuration of Cloudwatch alarms
class AlarmDiff < Diff
  include AlarmChange

  attr_accessor :policy_arn

  def diff_string
    diff_lines = [@local.name]

    case @type
    when ALARM
      lines = ["\tAlarm actions:"]
      lines << alarm_actions_to_remove.map { |a| "\t\t#{Colors.removed(a)}" }
      lines << alarm_actions_to_add.map { |a| "\t\t#{Colors.added(a)}" }
      diff_lines << lines.flatten.join("\n")
    when COMPARISON
      diff_lines << "\tComparison type: AWS - #{Colors.aws_changes(@aws.comparison_operator)}, Local - #{Colors.local_changes(@local.comparison)}"
    when DESCRIPTION
      diff_lines << [
        "\tDescription:",
        Colors.aws_changes("\t\tAWS - #{@aws.alarm_description}"),
        Colors.local_changes("\t\tLocal - #{@local.description}")
      ].join("\n")
    when DIMENSIONS
      lines = ["\tDimensions:"]
      lines << dimensions_to_remove.map { |d| "\t\t#{Colors.removed(d)}" }
      lines << dimensions_to_add.map { |d| "\t\t#{Colors.added(d)}" }
      diff_lines << lines.flatten.join("\n")
    when ENABLED
      diff_lines << "\tActions enabled: AWS - #{Colors.aws_changes(@aws.actions_enabled)}, Local - #{Colors.local_changes(@local.actions_enabled)}"
    when EVALUATION
      diff_lines << "\tEvaluation periods: AWS - #{Colors.aws_changes(@aws.evaluation_periods)}, Local - #{Colors.local_changes(@local.evaluation_periods)}"
    when INSUFFICIENT
      lines = ["\tInsufficient data actions:"]
      lines << insufficient_actions_to_remove.map { |i| "\t\t#{Colors.removed(i)}" }
      lines << insufficient_actions_to_add.map { |i| "\t\t#{Colors.added(i)}" }
      diff_lines << lines.flatten.join("\n")
    when METRIC
      diff_lines << "\tMetric: AWS - #{Colors.aws_changes(@aws.metric_name)}, Local - #{Colors.local_changes(@local.metric)}"
    when NAMESPACE
      diff_lines << "\tNamespace: AWS - #{Colors.aws_changes(@aws.namespace)}, Local - #{Colors.local_changes(@local.namespace)}"
    when OK
      lines = ["\tOk actions:"]
      lines << ok_actions_to_remove.map { |o| "\t\t#{Colors.removed(o)}" }
      lines << ok_actions_to_add.map { |o| "\t\t#{Colors.added(o)}" }
      diff_lines << lines.flatten.join("\n")
    when PERIOD
      diff_lines << "\tPeriod seconds: AWS - #{Colors.aws_changes(@aws.period)}, Local - #{Colors.local_changes(@local.period)}"
    when STATISTIC
      diff_lines << "\tStatistic: AWS - #{Colors.aws_changes(@aws.statistic)}, Local - #{Colors.local_changes(@local.statistic)}"
    when THRESHOLD
      diff_lines << "\tThreshold: AWS - #{Colors.aws_changes(@aws.threshold)}, Local - #{Colors.local_changes(@local.threshold)}"
    when UNIT
      diff_lines << "\tUnit: AWS - #{Colors.aws_changes(@aws.unit)}, Local - #{Colors.local_changes(@local.unit)}"
    end

    diff_lines.flatten.join("\n")
  end

  def asset_type
    "Alarm"
  end

  def aws_name
    @aws.alarm_name
  end

  # Public: Get the alarm actions that will be removed
  #
  # Returns an array of arns to remove
  def alarm_actions_to_remove
    @aws.alarm_actions - local_actions("alarm")
  end

  # Public: Get the alarm actions that will be added
  #
  # Returns an array of arns to add
  def alarm_actions_to_add
    local_actions("alarm") - @aws.alarm_actions
  end

  # Public: Get the dimensions that will be removed
  #
  # Returns a hash of key value pairs to be removed
  def dimensions_to_remove
    aws_dimensions.reject { |k, v| @local.dimensions.include?(k) and @local.dimensions[k] == v }
  end

  # Public: Get the dimensions that will be added
  #
  # Returns a hash of key value pairs to add
  def dimensions_to_add
    @local.dimensions.reject { |k, v| aws_dimensions.include?(k) and aws_dimensions[k] == v }
  end

  # Public: Get the insufficient data actions that will be removed
  #
  # Returns an array of arns to remove
  def insufficient_actions_to_remove
    @aws.insufficient_data_actions - local_actions("insufficient-data")
  end

  # Public: Get the insufficient data actions that will be added
  #
  # Returns an array of arns to add
  def insufficient_actions_to_add
    local_actions("insufficient-data") - @aws.insufficient_data_actions
  end

  # Public: Get the ok actions that will be removed
  #
  # Returns an array of arns to remove
  def ok_actions_to_remove
    @aws.ok_actions - local_actions("ok")
  end

  # Public: Get the ok actions that will be added
  #
  # Returns an array of arns to add
  def ok_actions_to_add
    local_actions("ok") - @aws.ok_actions
  end

  private

  # Internal: Get the actions defined locally for a particular state
  #
  # Returns an array of arns
  def local_actions(state)
    local_policies = []
    if @local.action_states.include?(state)
      local_policies << @policy_arn
    end
    local_policies
  end

  # Internal: Get the AWS dimensions in the same format as local configuration
  #
  # Returns a hash of key value pairs
  def aws_dimensions
    @aws_dimensions ||= Hash[@aws.dimensions.map { |d| [d.name, d.value] }]
  end

end
