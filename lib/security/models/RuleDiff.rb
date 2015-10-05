require "common/models/Diff"
require "util/Colors"

module Cumulus
  module SecurityGroups
    # Public: The types of changes that can be made to security group rules
    module RuleChange
      include Common::DiffChange

      REMOVED = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local rule configuration and AWS
    # configuration of security group rules
    class RuleDiff < Common::Diff
      include RuleChange

      # Public: Static method that will produce a diff that contains an added rule
      #
      # local - the local configuration that was added
      #
      # Returns the diff
      def RuleDiff.added(local)
        RuleDiff.new(ADD, nil, local)
      end

      # Public: Static method that will produce a diff that contains a removed rule
      #
      # aws - the aws configuration that was removed
      #
      # Returns the diff
      def RuleDiff.removed(aws)
        RuleDiff.new(REMOVED, aws)
      end

      def to_s
        case @type
        when ADD
          Colors.added("#{to_readable(local)}")
        when REMOVED
          Colors.removed("#{to_readable(aws)}")
        end
      end

      private

      # Internal: Produce a human readable string from a config hash
      #
      # config - the config to process
      #
      # Returns the human readable string
      def to_readable(config)
        # yes, for real, AWS returns the STRING "-1" if all protocols are allowed
        protocol = if config.protocol == "-1" then "All" else config.protocol end
        allowed = (config.security_groups + config.subnets).join(", ")

        temp = "Allowed: #{allowed}, Protocol: #{protocol}, "
        if protocol.downcase == "icmp"
          temp << "Type: #{config.from}, Code: #{config.to}"
        elsif config.from != config.to
          temp << "Ports: #{config.from}-#{config.to}"
        elsif config.from.nil?
          temp << "Ports: All"
        else
          temp << "Port: #{config.from}"
        end
        temp
      end

    end
  end
end
