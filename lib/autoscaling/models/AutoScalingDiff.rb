require "common/models/Diff"
require "util/Colors"

# Public: The types of changes that can be made to an AutoScaling Group
module AutoScalingChange
  include DiffChange

  MIN = DiffChange::next_change_id
  MAX = DiffChange::next_change_id
  DESIRED = DiffChange::next_change_id
  METRICS = DiffChange::next_change_id
  CHECK_TYPE = DiffChange::next_change_id
  CHECK_GRACE = DiffChange::next_change_id
  LOAD_BALANCER = DiffChange::next_change_id
  SUBNETS = DiffChange::next_change_id
  TAGS = DiffChange::next_change_id
  TERMINATION = DiffChange::next_change_id
  COOLDOWN = DiffChange::next_change_id
  LAUNCH = DiffChange::next_change_id
  SCHEDULED = DiffChange::next_change_id
  POLICY = DiffChange::next_change_id
end

# Public: Represents a single difference between local configuration and AWS
# configuration of AutoScaling Groups
class AutoScalingDiff < Diff
  include AutoScalingChange

  attr_accessor :scheduled_diffs
  attr_accessor :policy_diffs

  # Public: Static method that will produce a diff that contains changes in
  # scheduled actions
  #
  # local           - the local configuration
  # scheduled_diffs - the differences in scheduled actions
  #
  # Returns the diff
  def AutoScalingDiff.scheduled(local, scheduled_diffs)
    diff = AutoScalingDiff.new(SCHEDULED, nil, local)
    diff.scheduled_diffs = scheduled_diffs
    diff
  end

  # Public: Static method that will produce a diff that contains changes in
  # scaling policies
  #
  # local        - the local configuration
  # policy_diffs - the differences in scaling policies
  #
  # Returns the diff
  def AutoScalingDiff.policies(local, policy_diffs)
    diff = AutoScalingDiff.new(POLICY, nil, local)
    diff.policy_diffs = policy_diffs
    diff
  end

  def diff_string
    case @type
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
    when POLICY
      lines = ["Scaling policies:"]
      lines << policy_diffs.map { |d| "\t#{d}" }
      lines.flatten.join("\n")
    end
  end

  def asset_type
    "Autoscaling group"
  end

  def aws_name
    @aws.auto_scaling_group_name
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
