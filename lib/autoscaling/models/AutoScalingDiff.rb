require "util/Colors"

# Public: The types of changes that can be made to an AutoScaling Group
module AutoScalingChange
  ADD = 1
  UNMANAGED = 2
  MIN = 3
  MAX = 4
  DESIRED = 5
  METRICS = 6
  CHECK_TYPE = 7
  CHECK_GRACE = 8
  LOAD_BALANCER = 9
  SUBNETS = 10
  TAGS = 11
  TERMINATION = 12
  COOLDOWN = 13
end

# Public: Represents a single difference between local configuration and AWS
# configuration of AutoScaling Groups
class AutoScalingDiff
  include AutoScalingChange

  attr_reader :type

  # Public: Static method that will produce an "unmanaged" diff
  #
  # aws - the aws resource that is unmanaged
  #
  # Returns the diff
  def AutoScalingDiff.unmanaged(aws)
    AutoScalingDiff.new(UNMANAGED, aws)
  end

  # Public: Static method that will produce an "added" diff
  #
  # local - the local configuration that is added
  #
  # Returns the diff
  def AutoScalingDiff.added(local)
    AutoScalingDiff.new(ADD, nil, local)
  end

  # Public: Constructor
  #
  # type  - the type of difference between them
  # aws   - the aws resource that's different (defaults to nil)
  # local - the local resource that's different (defaults to nil)
  def initialize(type, aws = nil, local = nil)
    @aws = aws
    @local = local
    @type = type
  end

  def to_s
    case @type
    when ADD
      Colors.added("AutoScaling Group #{@local.name} will be created")
    when UNMANAGED
      Colors.unmanaged("AutoScaling Group #{@aws.auto_scaling_group_name} is unmanaged by Cumulus")
    when MIN
      "Min size: AWS - #{Colors.aws_changes(@aws.min_size)}, Local - #{Colors.local_changes(@local.min)}"
    when MAX
      "Max size: AWS - #{Colors.aws_changes(@aws.max_size)}, Local - #{Colors.local_changes(@local.max)}"
    when DESIRED
      "Desired size: AWS - #{Colors.aws_changes(@aws.desired_capacity)}, Local - #{Colors.local_changes(@local.desired)}"
    when METRICS
      lines = ["Enabled Metrics:"]
      lines << (@aws.enabled_metrics - @local.enabled_metrics).map { |m| "\t#{Colors.removed(m)}" }
      lines << (@local.enabled_metrics - @aws.enabled_metrics).map { |m| "\t#{Colors.added(m)}" }
      lines.flatten.join("\n")
    when CHECK_TYPE
      "Health check type: AWS - #{Colors.aws_changes(@aws.health_check_type)}, Local - #{Colors.local_changes(@local.check_type)}"
    when CHECK_GRACE
      "Health check grace period: AWS - #{Colors.aws_changes(@aws.health_check_grace_period)}, Local - #{Colors.local_changes(@local.check_grace)}"
    when LOAD_BALANCER
      lines = ["Load balancers:"]
      lines << (@aws.load_balancer_names - @local.load_balancers).map { |l| "\t#{Colors.removed(l)}" }
      lines << (@local.load_balancers - @aws.load_balancer_names).map { |l| "\t#{Colors.added(l)}" }
      lines.flatten.join("\n")
    when SUBNETS
      lines = ["Subnets:"]
      aws_subnets = @aws.vpc_zone_identifier.split(",")
      lines << (aws_subnets - @local.subnets).map { |s| "\t#{Colors.removed(s)}" }
      lines << (@local.subnets - aws_subnets).map { |s| "\t#{Colors.added(s)}" }
      lines.flatten.join("\n")
    when TAGS
      lines = ["Tags:"]
      aws_tags = Hash[@aws.tags.map { |tag| [tag.key, tag.value] }]
      lines << aws_tags.reject { |t| @local.tags.include?(t) }.map { |k, v| "\t#{Colors.removed("#{k} => #{v}")}" }
      lines << @local.tags.reject { |t| aws_tags.include?(t) }.map { |k, v| "\t#{Colors.added("#{k} => #{v}")}" }
      lines.flatten.join("\n")
    when TERMINATION
      lines = ["Termination policies:"]
      lines << (@aws.termination_policies - @local.termination).map { |t| "\t#{Colors.removed(t)}" }
      lines << (@local.termination - @aws.termination_policies).map { |t| "\t#{Colors.added(t)}" }
      lines.flatten.join("\n")
    when COOLDOWN
      "Cooldown: AWS - #{Colors.aws_changes(@aws.default_cooldown)}, Local - #{Colors.local_changes(@local.cooldown)}"
    end
  end

end
