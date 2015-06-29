require "autoscaling/loader/Loader"
require "autoscaling/models/AutoScalingDiff"
require "autoscaling/models/ScheduledActionDiff"
require "util/Colors"

require "aws-sdk"

# Public: The main class for the AutoScaling management module
class AutoScaling

  # Public: Constructor. Initializes the AWS client.
  def initialize
    @aws = Aws::AutoScaling::Client.new(
      region: Configuration.instance.region
    )
  end

  # Public: Print a diff between local configuration and configuration in AWS
  def diff
    each_difference do |name, diffs|
      if diffs.size > 0
        if diffs.size == 1 and (diffs[0].type == AutoScalingChange::ADD or
          diffs[0].type == AutoScalingChange::UNMANAGED)
          puts diffs[0]
        else
          puts "AutoScaling Group #{name} has the following changes:"
          diffs.each do |diff|
            diff_string = diff.to_s.lines.map {|s| "\t#{s}" }.join
            puts diff_string
          end
        end
      end
    end
  end

  # Public: Sync local configuration to AWS
  def sync
    each_difference do |name, diffs|
      if diffs.size > 0
        if diffs[0].type == AutoScalingChange::UNMANAGED
          puts diffs[0]
        elsif diffs[0].type == AutoScalingChange::ADD
          puts Colors.added("creating #{name}...")
          create_group(diffs[0].local)
        else
          puts Colors.blue("updating #{name}...")
          update_group(diffs[0].local, diffs)
        end
      end
    end
  end

  private

  # Internal: Loop through the differences between local configuration and AWS
  #
  # f - Will pass the name of the group and an array of AutoScalingDiffs
  #     to the block passed to this function
  def each_difference(&f)
    locals = Hash[Loader.groups.map { |local| [local.name, local] }]
    aws = Hash[aws_groups.map { |aws| [aws.auto_scaling_group_name, aws] }]

    aws.each do |name, group|
      f.call(name, [AutoScalingDiff.unmanaged(group)]) if !locals.include?(name)
    end
    locals.each do |name, group|
      if !aws.include?(name)
        f.call(name, [AutoScalingDiff.added(group)])
      else
        scheduled_actions = @aws.describe_scheduled_actions({
          auto_scaling_group_name: name
        }).scheduled_update_group_actions
        f.call(name, group.diff(aws[name], scheduled_actions))
      end
    end
  end

  # Internal: Create an AutoScaling Group
  #
  # group - the group to create
  def create_group(group)
    @aws.create_auto_scaling_group(gen_autoscaling_aws_hash(group))
    update_tags(group, {}, group.tags)
    update_load_balancers(group, [], group.load_balancers)
    update_scheduled_actions(group, [], group.scheduled.map { |k, v| k })
    if group.enabled_metrics.size > 0
      update_metrics(group, [], group.enabled_metrics)
    end
  end

  # Internal: Update an AutoScaling Group
  #
  # group - the group to update
  # diffs - the diffs between local and AWS configuration
  def update_group(group, diffs)
    hash = gen_autoscaling_aws_hash(group)
    if !Configuration.instance.autoscaling.override_launch_config_on_sync
      hash.delete(:launch_configuration_name)
    end
    @aws.update_auto_scaling_group(hash)
    diffs.each do |diff|
      if diff.type == AutoScalingChange::TAGS
        update_tags(group, diff.tags_to_remove, diff.tags_to_remove)
      elsif diff.type == AutoScalingChange::LOAD_BALANCER
        update_load_balancers(group, diff.load_balancers_to_remove, diff.load_balancers_to_add)
      elsif diff.type == AutoScalingChange::METRICS
        update_metrics(group, diff.metrics_to_disable, diff.metrics_to_enable)
      elsif diff.type == AutoScalingChange::SCHEDULED
        remove = diff.scheduled_diffs.reject do |d|
          d.type != ScheduledActionChange::UNMANAGED
        end.map { |d| d.aws.scheduled_action_name }
        update = diff.scheduled_diffs.select do |d|
          d.type != ScheduledActionChange::UNMANAGED
        end.map { |d| d.local.name }
        update_scheduled_actions(group, remove, update)
      end
    end
  end

  # Internal: Generate the object that AWS expects to create or update an
  # AutoScaling group
  #
  # group - the configuration object to use when generating the object
  #
  # Returns a hash of the information that AWS expects
  def gen_autoscaling_aws_hash(group)
    {
      auto_scaling_group_name: group.name,
      min_size: group.min,
      max_size: group.max,
      desired_capacity: group.desired,
      default_cooldown: group.cooldown,
      health_check_type: group.check_type,
      health_check_grace_period: group.check_grace,
      vpc_zone_identifier: group.subnets.size > 0 ? group.subnets.join(",") : nil,
      termination_policies: group.termination,
      launch_configuration_name: group.launch
    }
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

  # Internal: Get the AutoScaling Groups currently defined in AWS
  #
  # Returns an array of AutoScaling Groups
  def aws_groups
    @aws_groups ||= @aws.describe_auto_scaling_groups.auto_scaling_groups
  end
end
