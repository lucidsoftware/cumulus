require "autoscaling/models/AutoScalingDiff"

# Public: An object representing the configuration for an AutoScaling group.
class GroupConfig
  attr_reader :check_grace, :check_type, :enabled_metrics, :desired
  attr_reader :load_balancers, :max, :min, :name, :subnets, :tags, :termination

  # Public: Constructor
  #
  # json - a hash containing the json configuration for the AutoScaling group
  def initialize(json)
    @name = json["name"]
    @min = json["size"]["min"]
    @max = json["size"]["max"]
    @desired = json["size"]["desired"]
    @enabled_metrics = json["enabled-metrics"]
    @check_type = json["health-check-type"]
    @check_grace = json["health-check-grace-seconds"]
    @load_balancers = json["load-balancers"]
    @subnets = json["subnets"]
    @tags = json["tags"]
    @termination = json["termination"]
  end

  # Public: Produce the differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the aws resource
  #
  # Returns an Array of the AutoScalingDiffs that were found
  def diff(aws)
    diffs = []

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

    diffs
  end
end
