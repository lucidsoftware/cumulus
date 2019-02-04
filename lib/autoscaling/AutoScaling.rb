require "conf/Configuration"

require "aws-sdk-autoscaling"

module Cumulus
  module AutoScaling
    class << self
      @@client = Aws::AutoScaling::Client.new(Configuration.instance.client)

      # Public
      #
      # Returns an array of instance ids that are in any autoscaling groups
      def instance_ids
        @instance_ids ||= groups.map { |gr| gr.instances.map { |i| i.instance_id } }.flatten
      end

      # Public
      #
      # Returns a Hash of autoscaling group name to Aws::AutoScaling::Types::AutoScalingGroup
      def named_groups
        @named_groups ||= Hash[groups.map { |group| [group.auto_scaling_group_name, group] }]
      end

      # Public: Lazily load auto scaling groups
      def groups
        @groups = init_groups
      end

      private

      # Internal: Load all auto scaling groups
      #
      # Returns an array of Aws::AutoScaling::Types::AutoScalingGroup
      def init_groups
        @@client.describe_auto_scaling_groups.auto_scaling_groups
      end

    end
  end
end
