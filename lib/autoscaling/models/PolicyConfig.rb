require "autoscaling/models/AlarmConfig"
require "autoscaling/models/AlarmDiff"
require "autoscaling/models/PolicyDiff"
require "conf/Configuration"

require "aws-sdk"

# Public: A class that encapsulates data about the way a scaling policy is
# configured.
class PolicyConfig
  attr_reader :adjustment
  attr_reader :adjustment_type
  attr_reader :alarms
  attr_reader :cooldown
  attr_reader :min_adjustment
  attr_reader :name

  # Public: Constructor
  #
  # json - a hash representing the JSON configuration for this scaling policy
  def initialize(json)
    @@cloudwatch ||= Aws::CloudWatch::Client.new(
      region: Configuration.instance.region
    )

    @name = json["name"]
    @adjustment_type = json["adjustment-type"]
    @adjustment = json["adjustment"]
    @cooldown = json["cooldown"]
    @min_adjustment = json["min-adjustment-step"]
    @alarms = {}
    if !json["alarms"].nil?
      @alarms = Hash[json["alarms"].map { |alarm| [alarm["name"], AlarmConfig.new(alarm)] }]
    end
  end

  # Public: Produce the differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the scaling policy in AWS
  def diff(aws)
    diffs = []

    if @adjustment_type != aws.adjustment_type
      diffs << PolicyDiff.new(PolicyChange::ADJUSTMENT_TYPE, aws, self)
    end
    if @adjustment != aws.scaling_adjustment
      diffs << PolicyDiff.new(PolicyChange::ADJUSTMENT, aws, self)
    end
    if @cooldown != aws.cooldown
      diffs << PolicyDiff.new(PolicyChange::COOLDOWN, aws, self)
    end
    if @min_adjustment != aws.min_adjustment_step
      diffs << PolicyDiff.new(PolicyChange::MIN_ADJUSTMENT, aws, self)
    end

    # get all cloudwatch alarms that trigger this policy as their action
    aws_alarms = @@cloudwatch.describe_alarms({
      action_prefix: aws.policy_arn
    }).metric_alarms
    alarm_diffs = diff_alarms(aws_alarms, aws.policy_arn)
    if !alarm_diffs.empty?
      diffs << PolicyDiff.alarms(alarm_diffs, self, aws.policy_arn)
    end

    diffs
  end

  private

  # Internal: Determine changes in alarms
  #
  # aws_alarms - the Cloudwatch alarms in AWS
  # policy_arn - the policy arn is the action the alarms for this policy should
  #              take
  #
  # Returns an array of AlarmDiff's that represent differences between local and
  # AWS configuration.
  def diff_alarms(aws_alarms, policy_arn)
    diffs = []

    aws_alarms = Hash[aws_alarms.map { |a| [a.alarm_name, a] }]
    aws_alarms.reject { |k, v| @alarms.include?(k) }.each do |name, aws|
      diffs << AlarmDiff.unmanaged(aws)
    end
    @alarms.each do |name, local|
      if !aws_alarms.include?(name)
        diffs << AlarmDiff.added(local)
      else
        diffs << local.diff(aws_alarms[name], policy_arn)
      end
    end

    diffs.flatten
  end

end
