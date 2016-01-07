require "conf/Configuration"
require "security/models/RuleConfig"
require "security/models/RuleDiff"
require "security/models/RuleMigration"
require "security/models/SecurityGroupDiff"

require "json"

module Cumulus
  module SecurityGroups
    # Public: An object representing configuration for a security group
    class SecurityGroupConfig

      attr_reader :description
      attr_reader :inbound
      attr_reader :name
      attr_reader :outbound
      attr_reader :tags
      attr_reader :vpc_id

      # Public: Constructor.
      #
      # name - the name of the security group
      # vpc_id - the id of the vpc the security group belongs in
      # json - a hash containing the JSON configuration for the security group
      def initialize(name, vpc_id, json = nil)
        @name = name
        @vpc_id = vpc_id
        if !json.nil?
          @description = if !json["description"].nil? then json["description"] else "" end
          @tags = if !json["tags"].nil? then json["tags"] else {} end
          @inbound = json["rules"]["inbound"].map(&RuleConfig.method(:expand_ports)).flatten
          @outbound = if !json["rules"]["outbound"].nil?
            json["rules"]["outbound"].map(&RuleConfig.method(:expand_ports)).flatten
          else
            if Configuration.instance.security.outbound_default_all_allowed
              [RuleConfig.allow_all]
            else
              []
            end
          end
        end
      end

      # Public: Produce an array of the differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the aws resource
      #
      # Returns an array of the SecurityGroupDiffs that were found
      def diff(aws)
        diffs = []

        if @description != aws.description
          diffs << SecurityGroupDiff.new(SecurityGroupChange::DESCRIPTION, aws, self)
        end

        if @tags != Hash[aws.tags.map { |t| [t.key, t.value] }]
          diffs << SecurityGroupDiff.new(SecurityGroupChange::TAGS, aws, self)
        end

        inbound_diffs = diff_rules(@inbound, aws.ip_permissions)
        if !inbound_diffs.empty?
          diffs << SecurityGroupDiff.inbound(aws, self, inbound_diffs)
        end

        outbound_diffs = diff_rules(@outbound, aws.ip_permissions_egress)
        if !outbound_diffs.empty?
          diffs << SecurityGroupDiff.outbound(aws, self, outbound_diffs)
        end

        diffs
      end

      # Public: Populate this SecurityGroupConfig from an AWS resource
      #
      # aws             - the aws resource
      def populate!(aws)
        @description = aws.description
        @vpc_id = aws.vpc_id
        @tags = Hash[aws.tags.map { |t| [t.key, t.value] }]
        @inbound = combine_rules(aws.ip_permissions.map { |rule| RuleConfig.from_aws(rule) })
        @outbound = combine_rules(aws.ip_permissions_egress.map { |rule| RuleConfig.from_aws(rule) })
      end

      # Public: Get the config as a prettified JSON string.
      #
      # Returns the JSON string
      def pretty_json
        JSON.pretty_generate({
          "description" => @description,
          "tags" => @tags,
          "rules" => {
            "inbound" => @inbound.map(&:hash),
            "outbound" => @outbound.map(&:hash),
          }
        }.reject { |k, v| v.nil? })
      end

      private

      # Internal: Determine changes in rules
      #
      # local_rules     - the rules defined locally
      # aws_rules       - the rules in AWS
      #
      # Returns an array of RuleDiffs that represent differences between local and AWS configuration
      def diff_rules(local_rules, aws_rules)
        diffs = []

        # get the aws config into a format that mirrors cumulus so we can compare
        aws = aws_rules.map do |rule|
          RuleConfig.from_aws(rule)
        end
        aws_hashes = aws.flat_map(&:hash)
        local_hashes = local_rules.flat_map(&:hash)

        diffs << local_hashes.reject { |i| aws_hashes.include?(i) }.map { |l| RuleDiff.added(RuleConfig.new(l)) }
        diffs << aws_hashes.reject { |a| local_hashes.include?(a) }.map { |a| RuleDiff.removed(RuleConfig.new(a)) }

        diffs.flatten
      end

      # Internal: Combine rules that have the same ports and security groups to create the compact version
      # used by cumulus config.
      #
      # rules - an array of the rules to combine
      #
      # Returns an array of compact rules
      def combine_rules(rules)
        # separate out icmp rules
        all_rules = rules.map(&RuleMigration.method(:from_rule_config))
        icmp_rules = all_rules.select { |rule| rule.protocol == "icmp" }

        # first we find the ones that have the same protocol and port
        other_rules = all_rules.reject { |rule| rule.protocol == "icmp" }.group_by do |rule|
          [rule.protocol, rule.ports]
        # next, we combine the matching rules together
        end.flat_map do |_, matches|
          if matches.size == 1
            matches
          else
            matches[1..-1].inject(matches[0]) { |prev, cur| prev.combine_allowed(cur) }
          end
        # now, try to find ones that have the same groups of allowed entities and protocol
        end.group_by do |rule|
          [rule.protocol, rule.security_groups, rule.subnets]
        # finally, we'll combine ports for the matches
        end.flat_map do |_, matches|
          if matches.size == 1
            matches
          else
            matches[1..-1].inject(matches[0]) { |prev, cur| prev.combine_ports(cur) }
          end
        end

        icmp_rules + other_rules
      end
    end
  end
end
