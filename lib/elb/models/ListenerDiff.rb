require "common/models/Diff"
require "util/Colors"

module Cumulus
  module ELB
    # Public: The types of changes that can be made to an access log config
    module ListenerChange
      include Common::DiffChange

      LB_PROTOCOL = Common::DiffChange.next_change_id
      LB_PORT = Common::DiffChange.next_change_id
      INST_PROTOCOL = Common::DiffChange.next_change_id
      INST_PORT = Common::DiffChange.next_change_id
      SSL = Common::DiffChange.next_change_id
      POLICIES = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and
    # an AWS Load Balancer Listener
    class ListenerDiff < Common::Diff
      include ListenerChange

      attr_accessor :policies

      def asset_type
        "Listener for port"
      end

      def aws_name
        "#{aws.listener.load_balancer_port}"
      end

      def local_name
        "#{local.load_balancer_port}"
      end

      def unmanaged_string
        "will be deleted."
      end

      def self.policies(aws, local)
        added = local - aws
        removed = aws - local
        diff = ListenerDiff.new(POLICIES, aws, local)
        diff.policies = Common::ListChange.new(added, removed)
        diff
      end

      def diff_string
        case @type
        when LB_PROTOCOL
          [
            "load balancer protocol:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when LB_PORT
          [
            "load balancer port:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when INST_PROTOCOL
          [
            "instance protocol:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when INST_PORT
          [
            "instance port:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when SSL
          [
            "ssl certificate id:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when POLICIES
          [
            "policies:",
            @policies.removed.map { |p| Colors.removed("\t#{p}") },
            @policies.added.map { |p| Colors.added("\t#{p}") },
          ].flatten.join("\n")
        end
      end
    end
  end
end
