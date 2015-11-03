require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module AutoScaling
    class << self
      @@client = Aws::AutoScaling::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)

      # Public
      #
      # Returns a Hash of autoscaling group name to Aws::AutoScaling::Types::AutoScalingGroup
      def named_groups
        @named_groups ||= Hash[groups.map { [group.auto_scaling_group_name, group] }]
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
