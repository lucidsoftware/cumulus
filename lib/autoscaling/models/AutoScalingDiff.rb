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
  LAUNCH = 14
  SCHEDULED = 15
end

# Public: Represents a single difference between local configuration and AWS
# configuration of AutoScaling Groups
class AutoScalingDiff
  include AutoScalingChange

  attr_reader :local, :type
  attr_accessor :scheduled_diffs

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

  # Public: Static method that will produce a diff that contains changes in
  # scheduled actions
  #
  # scheduled_diffs - the differences in scheduled actions
  #
  # Returns the diff
  def AutoScalingDiff.scheduled(scheduled_diffs)
    diff = AutoScalingDiff.new(SCHEDULED)
    diff.scheduled_diffs = scheduled_diffs
    diff
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
    when LAUNCH
      "Launch configuration: AWS - #{Colors.aws_changes(@aws.launch_configuration_name)}, Local - #{@local.launch}"
    when MIN
      "Min size: AWS - #{Colors.aws_changes(@aws.min_size)}, Local - #{Colors.local_changes(@local.min)}"
    when MAX
      "Max size: AWS - #{Colors.aws_changes(@aws.max_size)}, Local - #{Colors.local_changes(@local.max)}"
    when DESIRED
      "Desired size: AWS - #{Colors.aws_changes(@aws.desired_capacity)}, Local - #{Colors.local_changes(@local.desired)}"
    when METRICS
      lines = ["Enabled Metrics:"]
      lines << metrics_to_disable.map { |m| "\t#{Colors.removed(m)}" }
      lines << metrics_to_enable.map { |m| "\t#{Colors.added(m)}" }
      lines.flatten.join("\n")
    when CHECK_TYPE
      "Health check type: AWS - #{Colors.aws_changes(@aws.health_check_type)}, Local - #{Colors.local_changes(@local.check_type)}"
    when CHECK_GRACE
      "Health check grace period: AWS - #{Colors.aws_changes(@aws.health_check_grace_period)}, Local - #{Colors.local_changes(@local.check_grace)}"
    when LOAD_BALANCER
      lines = ["Load balancers:"]
      lines << load_balancers_to_remove.map { |l| "\t#{Colors.removed(l)}" }
      lines << load_balancers_to_add.map { |l| "\t#{Colors.added(l)}" }
      lines.flatten.join("\n")
    when SUBNETS
      lines = ["Subnets:"]
      aws_subnets = @aws.vpc_zone_identifier.split(",")
      lines << (aws_subnets - @local.subnets).map { |s| "\t#{Colors.removed(s)}" }
      lines << (@local.subnets - aws_subnets).map { |s| "\t#{Colors.added(s)}" }
      lines.flatten.join("\n")
    when TAGS
      lines = ["Tags:"]
      lines << tags_to_remove.map { |k, v| "\t#{Colors.removed("#{k} => #{v}")}" }
      lines << tags_to_add.map { |k, v| "\t#{Colors.added("#{k} => #{v}")}" }
      lines.flatten.join("\n")
    when TERMINATION
      lines = ["Termination policies:"]
      lines << (@aws.termination_policies - @local.termination).map { |t| "\t#{Colors.removed(t)}" }
      lines << (@local.termination - @aws.termination_policies).map { |t| "\t#{Colors.added(t)}" }
      lines.flatten.join("\n")
    when COOLDOWN
      "Cooldown: AWS - #{Colors.aws_changes(@aws.default_cooldown)}, Local - #{Colors.local_changes(@local.cooldown)}"
    when SCHEDULED
      lines = ["Scheduled Actions:"]
      lines << scheduled_diffs.map { |d| "\t#{d}" }
      lines.flatten.join("\n")
    end
  end

  # Public: Get the metrics to disable, ie. are in AWS but not in local
  # configuration.
  #
  # Returns an array of metrics
  def metrics_to_disable
    @aws.enabled_metrics - @local.enabled_metrics
  end

  # Public: Get the metrics to enable, ie. are in local configuration, but not
  # AWS.
  #
  # Returns an array of metrics
  def metrics_to_enable
    @local.enabled_metrics - @aws.enabled_metrics
  end

  # Public: Get the load balancers to remove, ie. are in AWS and not local
  # configuration
  #
  # Returns an array of load balancer names
  def load_balancers_to_remove
    @aws.load_balancer_names - @local.load_balancers
  end

  # Public: Get the load balancers to add, ie. are in local configuration but
  # not in AWS
  #
  # Returns an array of load balancer names
  def load_balancers_to_add
    @local.load_balancers - @aws.load_balancer_names
  end

  # Public: Get the tags that are in AWS that are not in local configuration
  #
  # Returns a hash of tags
  def tags_to_remove
    aws_tags.reject { |t, v| @local.tags.include?(t) and @local.tags[t] == v }
  end

  # Public: Get the tags that are in local configuration but not in AWS
  #
  # Returns a hash of tags
  def tags_to_add
    @local.tags.reject { |t, v| aws_tags.include?(t) and aws_tags[t] == v }
  end

  private

  # Internal: Get the tags in AWS as a hash of key to value
  #
  # Returns a hash of tags
  def aws_tags
    @aws_tags ||= Hash[@aws.tags.map { |tag| [tag.key, tag.value] }]
  end

end
