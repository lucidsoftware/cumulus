require "common/models/Diff"
require "common/models/TagsDiff"
require "security/models/RuleDiff"
require "util/Colors"

module Cumulus
  module SecurityGroups
    # Public: The types of changes that can be made to security groups
    module SecurityGroupChange
      include Common::DiffChange

      DESCRIPTION = Common::DiffChange::next_change_id
      TAGS = Common::DiffChange::next_change_id
      INBOUND = Common::DiffChange::next_change_id
      OUTBOUND = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    # of security groups
    class SecurityGroupDiff < Common::Diff
      include SecurityGroupChange
      include Common::TagsDiff

      attr_accessor :inbound_diffs
      attr_accessor :outbound_diffs

      # Public: Static method that will produce a diff that contains changes in inbound rules
      #
      # aws           - the aws configuration
      # local         - the local configuration
      # inbound_diffs - the differences in inbound rules
      #
      # Returns the diff
      def SecurityGroupDiff.inbound(aws, local, inbound_diffs)
        diff = SecurityGroupDiff.new(INBOUND, aws, local)
        diff.inbound_diffs = inbound_diffs
        diff
      end

      # Public: Static method that will produce a diff that contains changes in outbound rules
      #
      # aws            - the aws configuration
      # local          - the local configuration
      # outbound_diffs - the differences in outbound rules
      #
      # Returns the diff
      def SecurityGroupDiff.outbound(aws, local, outbound_diffs)
        diff = SecurityGroupDiff.new(OUTBOUND, aws, local)
        diff.outbound_diffs = outbound_diffs
        diff
      end

      def asset_type
        "Security group"
      end

      def aws_name
        @aws.vpc_group_name
      end

      def diff_string
        case @type
        when DESCRIPTION
          [
            "Description:",
            Colors.aws_changes("\tAWS - #{@aws.description}"),
            Colors.local_changes("\tLocal - #{@local.description}"),
            "\tUnfortunately, AWS's SDK does not allow updating the description."
          ].join("\n")
        when INBOUND
          lines = ["Inbound rules:"]
          lines << inbound_diffs.map { |d| "\t#{d}" }
          lines.flatten.join("\n")
        when OUTBOUND
          lines = ["Outbound rules:"]
          lines << outbound_diffs.map { |d| "\t#{d}" }
          lines.flatten.join("\n")
        when TAGS
          tags_diff_string
        end
      end

      # Public: Get the inbound rules to add
      #
      # Returns the added rules
      def added_inbounds
        inbound_diffs.reject { |i| i.type == RuleChange::REMOVED }.map(&:local)
      end

      # Public: Get the inbound rules to remove
      #
      # Returns the removed rules
      def removed_inbounds
        inbound_diffs.reject { |i| i.type == RuleChange::ADD }.map(&:aws)
      end

      # Public: Get the outbound rules to add
      #
      # Returns the added rules
      def added_outbounds
        outbound_diffs.reject { |o| o.type == RuleChange::REMOVED }.map(&:local)
      end

      # Public: Get the outbound rules to remove
      #
      # Returns the removed rules
      def removed_outbounds
        outbound_diffs.reject { |o| o.type == RuleChange::ADD }.map(&:aws)
      end
    end
  end
end
