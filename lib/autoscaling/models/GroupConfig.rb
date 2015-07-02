require "autoscaling/loader/Loader"
require "autoscaling/models/AutoScalingDiff"
require "autoscaling/models/PolicyConfig"
require "autoscaling/models/PolicyDiff"
require "autoscaling/models/ScheduledActionDiff"
require "autoscaling/models/ScheduledConfig"

# Public: An object representing the configuration for an AutoScaling group.
class GroupConfig
  attr_reader :availability_zones
  attr_reader :cooldown
  attr_reader :check_grace
  attr_reader :check_type
  attr_reader :enabled_metrics
  attr_reader :desired
  attr_reader :launch
  attr_reader :load_balancers
  attr_reader :max
  attr_reader :min
  attr_reader :name
  attr_reader :policies
  attr_reader :scheduled
  attr_reader :subnets
  attr_reader :tags
  attr_reader :termination

  # Public: Constructor
  #
  # name - the name of the group
  # json - a hash containing the json configuration for the AutoScaling group
  def initialize(name, json)
    @name = name
    @cooldown = json["cooldown-seconds"]
    @min = json["size"]["min"]
    @max = json["size"]["max"]
    @desired = json["size"]["desired"]
    @enabled_metrics = json["enabled-metrics"]
    @check_type = json["health-check-type"]
    @check_grace = json["health-check-grace-seconds"]
    @launch = json["launch-configuration"]
    @load_balancers = json["load-balancers"]
    @subnets = json["subnets"]
    @tags = json["tags"]
    @termination = json["termination"]
    @scheduled = Hash[json["scheduled"].map { |json| [json["name"], ScheduledConfig.new(json)] }]

    # load scaling policies
    static_policies = json["policies"]["static"].map { |file| Loader.static_policy(file) }
    template_policies = json["policies"]["templates"].map do |template|
      Loader.template_policy(template["template"], template["vars"])
    end
    inline_policies = json["policies"]["inlines"].map { |inline| PolicyConfig.new(inline) }
    @policies = static_policies + template_policies + inline_policies
    @policies = Hash[@policies.map { |policy| [policy.name, policy] }]
  end

  # Public: Produce the differences between this local configuration and the
  # configuration in AWS
  #
  # aws         - the aws resource
  # autoscaling - the AWS client needed to get additional AWS resources
  #
  # Returns an Array of the AutoScalingDiffs that were found
  def diff(aws, autoscaling)
    diffs = []

    if @cooldown != aws.default_cooldown
      diffs << AutoScalingDiff.new(AutoScalingChange::COOLDOWN, aws, self)
    end
    if @min != aws.min_size
      diffs << AutoScalingDiff.new(AutoScalingChange::MIN, aws, self)
    end
    if @max != aws.max_size
      diffs << AutoScalingDiff.new(AutoScalingChange::MAX, aws, self)
    end
    if @desired != aws.desired_capacity
      diffs << AutoScalingDiff.new(AutoScalingChange::DESIRED, aws, self)
    end
    if @enabled_metrics != aws.enabled_metrics
      diffs << AutoScalingDiff.new(AutoScalingChange::METRICS, aws, self)
    end
    if @check_type != aws.health_check_type
      diffs << AutoScalingDiff.new(AutoScalingChange::CHECK_TYPE, aws, self)
    end
    if @check_grace != aws.health_check_grace_period
      diffs << AutoScalingDiff.new(AutoScalingChange::CHECK_GRACE, aws, self)
    end
    if @launch != aws.launch_configuration_name
      diffs << AutoScalingDiff.new(AutoScalingChange::LAUNCH, aws, self)
    end
    if @load_balancers != aws.load_balancer_names
      diffs << AutoScalingDiff.new(AutoScalingChange::LOAD_BALANCER, aws, self)
    end
    if @subnets != aws.vpc_zone_identifier.split(",")
      diffs << AutoScalingDiff.new(AutoScalingChange::SUBNETS, aws, self)
    end
    if @tags != Hash[aws.tags.map { |tag| [tag.key, tag.value] }]
      diffs << AutoScalingDiff.new(AutoScalingChange::TAGS, aws, self)
    end
    if @termination != aws.termination_policies
      diffs << AutoScalingDiff.new(AutoScalingChange::TERMINATION, aws, self)
    end

    # check for changes in scheduled actions
    aws_scheduled = autoscaling.describe_scheduled_actions({
      auto_scaling_group_name: @name
    }).scheduled_update_group_actions
    scheduled_diffs = diff_scheduled(aws_scheduled)
    if !scheduled_diffs.empty?
      diffs << AutoScalingDiff.scheduled(scheduled_diffs)
    end

    # check for changes in scaling policies
    aws_policies = autoscaling.describe_policies({
      auto_scaling_group_name: @name
    }).scaling_policies
    policy_diffs = diff_policies(aws_policies)
    if !policy_diffs.empty?
      diffs << AutoScalingDiff.policies(policy_diffs)
    end

    diffs
  end

  private

  # Internal: Determine changes in scheduled actions.
  #
  # aws_scheduled - the scheduled actions in AWS
  #
  # Returns an array of ScheduledActionDiff's that represent difference between
  # local and AWS configuration
  def diff_scheduled(aws_scheduled)
    diffs = []

    aws_scheduled = Hash[aws_scheduled.map { |s| [s.scheduled_action_name, s] }]
    aws_scheduled.reject { |k, v| @scheduled.include?(k) }.each do |name, aws|
      diffs << ScheduledActionDiff.unmanaged(aws)
    end
    @scheduled.each do |name, local|
      if !aws_scheduled.include?(name)
        diffs << ScheduledActionDiff.added(local)
      else
        diffs << local.diff(aws_scheduled[name])
      end
    end

    diffs.flatten
  end

  # Internal: Determine changes in scaling policies.
  #
  # aws_policies - the scaling policies in AWS
  #
  # Returns an array of PolicyDiff's that represent differences between local
  # and AWS configuration
  def diff_policies(aws_policies)
    diffs = []

    aws_policies = Hash[aws_policies.map { |p| [p.policy_name, p] }]
    aws_policies.reject { |k, v| @policies.include?(k) }.each do |name, aws|
      diffs << PolicyDiff.unmanaged(aws)
    end
    @policies.each do |name, local|
      if !aws_policies.include?(name)
        diffs << PolicyDiff.added(local)
      else
        diffs << local.diff(aws_policies[name])
      end
    end

    diffs.flatten
  end

end
