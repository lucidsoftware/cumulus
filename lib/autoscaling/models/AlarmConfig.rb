require "autoscaling/models/AlarmDiff"

# Public: A class that encapsulates data about configuration for an autoscaling
# Cloudwatch alarm.
#
# The action to be taken is inferred to be activating the policy that contains
# the alarm. As such, we don't keep arrays of actions to take when various alarm
# states are triggered. We just apply the action (activating the policy) to the
# states contained in the `action_states` array. Valid values are "alarm", "ok",
# and "insufficient-data".
class AlarmConfig
  attr_reader :action_states
  attr_reader :actions_enabled
  attr_reader :comparison
  attr_reader :description
  attr_reader :dimensions
  attr_reader :evaluation_periods
  attr_reader :metric
  attr_reader :name
  attr_reader :namespace
  attr_reader :period
  attr_reader :statistic
  attr_reader :threshold
  attr_reader :unit

  # Public: Constructor
  #
  # json - a hash containing the JSON configuration for the alarm
  def initialize(json = nil)
    if !json.nil?
      @action_states = json["action-states"]
      @actions_enabled = json["actions-enabled"]
      @comparison = json["comparison"]
      @description = json["description"]
      @dimensions = json["dimensions"]
      @evaluation_periods = json["evaluation-periods"]
      @metric = json["metric"]
      @name = json["name"]
      @namespace = json["namespace"]
      @period = json["period-seconds"]
      @statistic = json["statistic"]
      @threshold = json["threshold"]
      @unit = json["unit"]
    end
  end

  # Public: Get the configuration as a hash
  #
  # Returns the hash
  def hash
    {
      "name" => @name,
      "action-states" => @action_states,
      "actions-enabled" => @actions_enabled,
      "comparison" => @comparison,
      "description" => @description,
      "dimensions" => @dimensions,
      "evaluation-periods" => @evaluation_periods,
      "metric" => @metric,
      "namespace" => @namespace,
      "period-seconds" => @period,
      "statistic" => @statistic,
      "threshold" => @threshold,
      "unit" => @unit
    }.reject { |k, v| v.nil? }
  end

  # Public: Populate the AlarmConfig from an existing AWS cloudwatch alarm
  #
  # policy_arn - the arn of the policy the alarm should be attached to
  # resource   - the aws resource to populate from
  def populate(policy_arn, resource)
    action_states = []
    if resource.ok_actions.include?(policy_arn) then action_states << "ok" end
    if resource.alarm_actions.include?(policy_arn) then action_states << "alarm" end
    if resource.insufficient_data_actions.include?(policy_arn) then action_states << "insufficient-data" end

    @action_states = action_states
    @actions_enabled = resource.actions_enabled
    @comparison = resource.comparison_operator
    @description = resource.alarm_description
    @dimensions = Hash[resource.dimensions.map { |d| [d.name, d.value] }]
    @evaluation_periods = resource.evaluation_periods
    @metric = resource.metric_name
    @name = resource.alarm_name
    @namespace = resource.namespace
    @period = resource.period
    @statistic = resource.statistic
    @threshold = resource.threshold
    @unit = resource.unit
  end

  # Public: Produce the differences between this local configuration and the
  # configuration in AWS
  #
  # aws        - the alarm in AWS
  # policy_arn - the policy arn is the action this alarm should take
  #
  # Returns an array of AlarmDiff objects representing the differences
  def diff(aws, policy_arn)
    diffs = []

    if @description != aws.alarm_description
      diffs << AlarmDiff.new(AlarmChange::DESCRIPTION, aws, self)
    end
    if @actions_enabled != aws.actions_enabled
      diffs << AlarmDiff.new(AlarmChange::ENABLED, aws, self)
    end
    if @comparison != aws.comparison_operator
      diffs << AlarmDiff.new(AlarmChange::COMPARISON, aws, self)
    end
    if @evaluation_periods != aws.evaluation_periods
      diffs << AlarmDiff.new(AlarmChange::EVALUATION, aws, self)
    end
    if @metric != aws.metric_name
      diffs << AlarmDiff.new(AlarmChange::METRIC, aws, self)
    end
    if @namespace != aws.namespace
      diffs << AlarmDiff.new(AlarmChange::NAMESPACE, aws, self)
    end
    if @period != aws.period
      diffs << AlarmDiff.new(AlarmChange::PERIOD, aws, self)
    end
    if @statistic != aws.statistic
      diffs << AlarmDiff.new(AlarmChange::STATISTIC, aws, self)
    end
    if @threshold != aws.threshold
      diffs << AlarmDiff.new(AlarmChange::THRESHOLD, aws, self)
    end
    if @unit != aws.unit
      diffs << AlarmDiff.new(AlarmChange::UNIT, aws, self)
    end
    aws_dimensions = Hash[aws.dimensions.map { |d| [d.name, d.value] }]
    if @dimensions != aws_dimensions
      diffs << AlarmDiff.new(AlarmChange::DIMENSIONS, aws, self)
    end

    ["ok", "alarm", "insufficient-data"].each do |state|
      case state
      when "ok"
        actions = aws.ok_actions
        change_type = AlarmChange::OK
      when "alarm"
        actions = aws.alarm_actions
        change_type = AlarmChange::ALARM
      when "insufficient-data"
        actions = aws.insufficient_data_actions
        change_type = AlarmChange::INSUFFICIENT
      end

      if (!@action_states.include?(state) and actions.size != 0) or
        (@action_states.include?(state) and (actions.size != 1 or actions[0] != policy_arn))
        diff = AlarmDiff.new(change_type, aws, self)
        diff.policy_arn = policy_arn
        diffs << diff
      end
    end

    diffs
  end
end
