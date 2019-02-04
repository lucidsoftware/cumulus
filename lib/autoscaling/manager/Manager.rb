require "autoscaling/AutoScaling"
require "autoscaling/loader/Loader"
require "autoscaling/models/AlarmDiff"
require "autoscaling/models/AutoScalingDiff"
require "autoscaling/models/ScheduledActionDiff"
require "common/manager/Manager"
require "util/Colors"

require "aws-sdk-autoscaling"
require "aws-sdk-cloudwatch"

module Cumulus
  module AutoScaling
    # Public: The main class for the AutoScaling management module
    class Manager < Common::Manager
      # Public: Constructor. Initializes the AWS client.
      def initialize
        super()
        @aws = Aws::AutoScaling::Client.new(Configuration.instance.client)
        @cloudwatch = Aws::CloudWatch::Client.new(Configuration.instance.client)
      end

      # Public: Migrate AWS Autoscaling to Cumulus configuration.
      def migrate
        groups_dir = "#{@migration_root}/groups"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(groups_dir)
          Dir.mkdir(groups_dir)
        end

        aws_resources.each do |name, resource|
          puts "Processing #{name}..."
          config = GroupConfig.new(resource.auto_scaling_group_name)
          config.populate(resource)
          config.populate_scheduled(@aws.describe_scheduled_actions({
            auto_scaling_group_name: resource.auto_scaling_group_name
          }).scheduled_update_group_actions)
          config.populate_policies(@aws.describe_policies({
            auto_scaling_group_name: resource.auto_scaling_group_name
          }).scaling_policies)

          puts "Writing #{resource.auto_scaling_group_name} configuration to file..."
          File.open("#{groups_dir}/#{config.name}.json", 'w') { |f| f.write(config.pretty_json) }
        end

      end

      def resource_name
        "AutoScaling Group"
      end

      def local_resources
        @local_resources ||= Hash[Loader.groups.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= AutoScaling::named_groups
      end

      def unmanaged_diff(aws)
        AutoScalingDiff.unmanaged(aws)
      end

      def added_diff(local)
        AutoScalingDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws, @aws)
      end

      private

      # Internal: Create an AutoScaling Group
      #
      # group - the group to create
      def create(group)

        hash = group.to_aws(true)

        # If there are local scheduled actions, override the min, max
        # and desired capacity if it exists on the last scheduled action
        last_scheduled = group.last_scheduled
        if last_scheduled
          hash[:min_size] = last_scheduled.min || hash[:min_size]
          hash[:max_size] = last_scheduled.max || hash[:max_size]
          hash[:desired_capacity] = last_scheduled.desired || hash[:desired_capacity]
        end

        @aws.create_auto_scaling_group(hash)
        update_tags(group, {}, group.tags)
        update_load_balancers(group, [], group.load_balancers)
        update_scheduled_actions(group, [], group.scheduled.map { |k, v| k })
        update_scaling_policies(group, [], group.policies.map { |k, v| k })
        if group.enabled_metrics.size > 0
          update_metrics(group, [], group.enabled_metrics)
        end

        # update alarms for each created scaling policy
        group.policies.each do |policy_name, policy|
          policy_arn = @aws.describe_policies({
            auto_scaling_group_name: group.name,
            policy_names: [policy_name]
          }).scaling_policies[0].policy_arn
          update_alarms(policy, policy_arn, [], policy.alarms.map { |k , v| k })
        end
      end

      # Internal: Update an AutoScaling Group
      #
      # group - the group to update
      # diffs - the diffs between local and AWS configuration
      def update(group, diffs)
        hash = group.to_aws(Configuration.instance.autoscaling.force_size)
        if !Configuration.instance.autoscaling.override_launch_config_on_sync
          hash.delete(:launch_configuration_name)
        end

        update_group = false

        diffs.each do |diff|
          case diff.type
          when AutoScalingChange::MIN
            update_group = true

            # Override the min size value because it could be different from the actual
            # configured min size if there were scheduled actions
            hash[:min_size] = diff.local
          when AutoScalingChange::MAX
            update_group = true

            # Override the max size value because it could be different from the actual
            # configured max size if there were scheduled actions
            hash[:max_size] = diff.local
          when AutoScalingChange::DESIRED
            update_group = true

            # Override the desired size value because it could be different from the actual
            # configured desired size if there were scheduled actions
            hash[:desired_capacity] = diff.local
          when AutoScalingChange::COOLDOWN,
               AutoScalingChange::CHECK_TYPE,
               AutoScalingChange::CHECK_GRACE,
               AutoScalingChange::SUBNETS,
               AutoScalingChange::TERMINATION,
               AutoScalingChange::LAUNCH
            update_group = true
          when AutoScalingChange::TAGS
            update_tags(group, diff.tags_to_remove, diff.tags_to_add)
          when AutoScalingChange::LOAD_BALANCER
            update_load_balancers(group, diff.load_balancers_to_remove, diff.load_balancers_to_add)
          when AutoScalingChange::METRICS
            update_metrics(group, diff.metrics_to_disable, diff.metrics_to_enable)
          when AutoScalingChange::SCHEDULED
            remove = diff.changes.removed.map { |d| d.aws.scheduled_action_name }
            update = (diff.changes.added + diff.changes.modified).map { |d| d.local.name }

            update_scheduled_actions(group, remove, update)
          when AutoScalingChange::POLICY
            remove = diff.policy_diffs.reject do |d|
              d.type != PolicyChange::UNMANAGED
            end.map { |d| d.aws.policy_name }
            update = diff.policy_diffs.select do |d|
              d.type !=  PolicyChange::UNMANAGED and d.type != PolicyChange::ALARM
            end.map { |d| d.local.name }
            update_scaling_policies(group, remove, update)

            # update alarms for existing policies
            alarms = diff.policy_diffs.select { |d| d.type == PolicyChange::ALARM }
            alarms.each do |policy_diff|
              remove = policy_diff.alarm_diffs.reject do |d|
                d.type != AlarmChange::UNMANAGED
              end.map { |d| d.aws.alarm_name }
              update = policy_diff.alarm_diffs.select do |d|
                d.type != AlarmChange::UNMANAGED
              end.map { |u| u.local.name }

              update_alarms(policy_diff.local, policy_diff.policy_arn, remove, update)
            end

            # create alarms for new policies
            new_policies = diff.policy_diffs.select { |d| d.type == PolicyChange::ADD }
            new_policies.each do |policy_diff|
              config = policy_diff.local
              policy_arn = @aws.describe_policies({
                auto_scaling_group_name: group.name,
                policy_names: [config.name]
              }).scaling_policies[0].policy_arn
              update_alarms(config, policy_arn, [], config.alarms.map {|k , v| k })
            end
          end
        end

        @aws.update_auto_scaling_group(hash) if update_group
      end

      # Internal: Update the tags for an autoscaling group.
      #
      # group   - the autoscaling group to update
      # remove  - the tags to remove
      # add     - the tags to add
      def update_tags(group, remove, add)
        @aws.delete_tags({
          tags: remove.map { |k, v|
            {
              key: k,
              resource_id: group.name,
              resource_type: "auto-scaling-group"
            }
          }
        })
        @aws.create_or_update_tags({
          tags: add.map { |k, v|
            {
              key: k,
              value: v,
              resource_id: group.name,
              resource_type: "auto-scaling-group",
              propagate_at_launch: true
            }
          }
        })
      end

      # Internal: Update the load balancers for an autoscaling group.
      #
      # group   - the autoscaling group to update
      # remove  - the load balancers to remove
      # add     - the load balancers to add
      def update_load_balancers(group, remove, add)
        @aws.detach_load_balancers({
          auto_scaling_group_name: group.name,
          load_balancer_names: remove
        })
        @aws.attach_load_balancers({
          auto_scaling_group_name: group.name,
          load_balancer_names: add
        })
      end

      # Internal: Update the metrics enabled for an autoscaling group.
      #
      # group   - the autoscaling group to update
      # disable - the metrics to disable
      # enable  - the metrics to enable
      def update_metrics(group, disable, enable)
        @aws.disable_metrics_collection({
          auto_scaling_group_name: group.name,
          metrics: disable
        })
        @aws.enable_metrics_collection({
          auto_scaling_group_name: group.name,
          metrics: enable,
          granularity: "1Minute"
        })
      end

      # Internal: Update the scheduled actions for an autoscaling group.
      #
      # group  - the group the scheduled actions belong to
      # remove - the names of the actions to remove
      # update - the names of the actions to update
      def update_scheduled_actions(group, remove, update)
        # remove any unmanaged scheduled actions
        remove.each do |name|
          puts Colors.blue("\tdeleting scheduled action #{name}...")
          @aws.delete_scheduled_action({
            auto_scaling_group_name: group.name,
            scheduled_action_name: name
          })
        end

        # update or create all scheduled actions that have changed in local config
        group.scheduled.each do |name, config|
          if update.include?(name)
            puts Colors.blue("\tupdating scheduled action #{name}...")
            @aws.put_scheduled_update_group_action({
              auto_scaling_group_name: group.name,
              scheduled_action_name: name,
              start_time: config.start,
              end_time: config.end,
              recurrence: config.recurrence,
              min_size: config.min,
              max_size: config.max,
              desired_capacity: config.desired
            })
          end
        end
      end

      # Internal: Update the scaling policies for an autoscaling group
      #
      # group   - the group the scaling policies belong to
      # remove  - the names of the scaling policies to remove
      # update  - the names of the scaling policies to update
      def update_scaling_policies(group, remove, update)
        # remove any unmanaged scaling policies
        remove.each do |name|
          @aws.delete_policy({
              auto_scaling_group_name: group.name,
              policy_name: name
          })
        end

        # update or create all policies that have changed in local config
        group.policies.each do |name, config|
          if update.include?(name)
            puts Colors.blue("\tupdating scaling policy #{name}...")
            @aws.put_scaling_policy({
              auto_scaling_group_name: group.name,
              policy_name: name,
              adjustment_type: config.adjustment_type,
              min_adjustment_step: config.min_adjustment,
              scaling_adjustment: config.adjustment,
              cooldown: config.cooldown
            })
          end
        end
      end

      # Internal: Update the cloudwatch alarms for a scaling policy
      #
      # policy     - the policy config the alarms belong to
      # policy_arn - the arn of the policy for which to update arns
      # remove     - the names of the alarms to remove
      # update     - the names of the alarms to create or update
      def update_alarms(policy, policy_arn, remove, update)
        @cloudwatch.delete_alarms({
          alarm_names: remove
        })

        policy.alarms.each do |name, config|
          if update.include?(name)
            puts Colors.blue("\tupdating cloudwatch alarm #{name}...")
            @cloudwatch.put_metric_alarm({
              alarm_name: config.name,
              alarm_description: config.description,
              actions_enabled: config.actions_enabled,
              metric_name: config.metric,
              namespace: config.namespace,
              statistic: config.statistic,
              dimensions: config.dimensions.map { |k, v| { name: k, value: v } },
              period: config.period,
              unit: config.unit,
              evaluation_periods: config.evaluation_periods,
              threshold: config.threshold,
              comparison_operator: config.comparison,
              ok_actions: config.action_states.include?("ok") ? [policy_arn] : nil,
              alarm_actions: config.action_states.include?("alarm") ? [policy_arn] : nil,
              insufficient_data_actions: config.action_states.include?("insufficient-data") ? [policy_arn] : nil
            }.reject { |k, v| v == nil })
          end
        end
      end

    end
  end
end
