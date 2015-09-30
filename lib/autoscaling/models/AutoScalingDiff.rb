require "common/models/Diff"
require "common/models/TagsDiff"
require "common/models/ListChange"
require "util/Colors"

module Cumulus
  module AutoScaling
    # Public: The types of changes that can be made to an AutoScaling Group
    module AutoScalingChange
      include Common::DiffChange

      MIN = Common::DiffChange::next_change_id
      MAX = Common::DiffChange::next_change_id
      DESIRED = Common::DiffChange::next_change_id
      METRICS = Common::DiffChange::next_change_id
      CHECK_TYPE = Common::DiffChange::next_change_id
      CHECK_GRACE = Common::DiffChange::next_change_id
      LOAD_BALANCER = Common::DiffChange::next_change_id
      SUBNETS = Common::DiffChange::next_change_id
      TAGS = Common::DiffChange::next_change_id
      TERMINATION = Common::DiffChange::next_change_id
      COOLDOWN = Common::DiffChange::next_change_id
      LAUNCH = Common::DiffChange::next_change_id
      SCHEDULED = Common::DiffChange::next_change_id
      POLICY = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of AutoScaling Groups
    class AutoScalingDiff < Common::Diff
      include AutoScalingChange
      include Common::TagsDiff

      attr_accessor :policy_diffs

      # Public: Static method that will produce a diff that contains changes in
      # scheduled actions
      #
      # aws - the array of AWS scheduled actions
      # local - the map of scheduled action name to local configuration
      #
      # Returns the AutoScalingDiff
      def AutoScalingDiff.scheduled(aws, local)
        aws_scheduled = Hash[aws.map { |s| [s.scheduled_action_name, s] }]

        removed = aws_scheduled.reject { |k, v| local.include?(k) }.map { |_, sched| ScheduledActionDiff.unmanaged(sched) }
        added = local.reject { |k, v| aws_scheduled.include? k }.map { |_, sched| ScheduledActionDiff.added(sched) }
        modified = local.select { |k, v| aws_scheduled.include? k }.map do |name, local_sched|
          aws_sched = aws_scheduled[name]
          sched_diffs = local_sched.diff(aws_sched)

          if !sched_diffs.empty?
            ScheduledActionDiff.modified(aws_sched, local_sched, sched_diffs)
          end
        end.reject { |v| !v }

        if !removed.empty? or !added.empty? or !modified.empty?
          diff = AutoScalingDiff.new(AutoScalingChange::SCHEDULED, aws, local)
          diff.changes = Common::ListChange.new(added, removed, modified)
          diff
        end
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
          "Min size: AWS - #{Colors.aws_changes(@aws)}, Local - #{Colors.local_changes(@local)}"
        when MAX
          "Max size: AWS - #{Colors.aws_changes(@aws)}, Local - #{Colors.local_changes(@local)}"
        when DESIRED
          "Desired size: AWS - #{Colors.aws_changes(@aws)}, Local - #{Colors.local_changes(@local)}"
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
          tags_diff_string
        when TERMINATION
          lines = ["Termination policies:"]
          lines << (@aws.termination_policies - @local.termination).map { |t| "\t#{Colors.removed(t)}" }
          lines << (@local.termination - @aws.termination_policies).map { |t| "\t#{Colors.added(t)}" }
          lines.flatten.join("\n")
        when COOLDOWN
          "Cooldown: AWS - #{Colors.aws_changes(@aws.default_cooldown)}, Local - #{Colors.local_changes(@local.cooldown)}"
        when SCHEDULED
          [
            "Scheduled Actions:",
            changes.removed.map { |added_diff| "\t#{added_diff}" },
            changes.added.map { |removed_diff| "\t#{removed_diff}" },
            changes.modified.map do |modified_diff|
              [
                "\t#{modified_diff.local.name}:",
                modified_diff.changes.map do |scheduled_diff|
                  scheduled_diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
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

    end
  end
end
