require "autoscaling/models/AutoScalingDiff"

# Public: An object representing the configuration for an AutoScaling group.
class GroupConfig
  attr_reader :availability_zones
  attr_reader :cooldown, :check_grace, :check_type, :enabled_metrics, :desired
  attr_reader :launch, :load_balancers, :max, :min, :name, :subnets, :tags
  attr_reader :termination

  # Public: Constructor
  #
  # json - a hash containing the json configuration for the AutoScaling group
  def initialize(json)
    @name = json["name"]
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
    @availability_zones = json["availability-zones"]
  end

  # Public: Produce the differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the aws resource
  #
  # Returns an Array of the AutoScalingDiffs that were found
  def diff(aws)
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
    if @availability_zones != aws.availability_zones
      diffs << AutoScalingDiff.new(AutoScalingChange::AVAILABILITY_ZONES, aws, self)
    end

    diffs
  end
end
