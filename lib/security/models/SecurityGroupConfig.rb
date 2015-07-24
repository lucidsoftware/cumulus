require "security/models/RuleConfig"
require "security/models/RuleDiff"
require "security/models/SecurityGroupDiff"

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
  # json - a hash containing the JSON configuration for the security group
  def initialize(name, json)
    @name = name
    if !json.nil?
      @description = json["description"]
      @vpc_id = json["vpc-id"]
      @tags = json["tags"]
      @inbound = json["rules"]["inbound"].map(&RuleConfig.method(:new))
      @outbound = json["rules"]["outbound"].map(&RuleConfig.method(:new))
    end
  end

  # Public: Produce an array of the differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the aws resource
  # sg_ids_to_names - a mapping of security group ids to their names
  #
  # Returns an array of the SecurityGroupDiffs that were found
  def diff(aws, sg_ids_to_names)
    diffs = []

    if @description != aws.description
      diffs << SecurityGroupDiff.new(SecurityGroupChange::DESCRIPTION, aws, self)
    end
    if @vpc_id != aws.vpc_id
      diffs << SecurityGroupDiff.new(SecurityGroupChange::VPC_ID, aws, self)
    end
    if @tags != Hash[aws.tags.map { |t| [t.key, t.value] }]
      diffs << SecurityGroupDiff.new(SecurityGroupChange::TAGS, aws, self)
    end

    inbound_diffs = diff_rules(@inbound, aws.ip_permissions, sg_ids_to_names)
    if !inbound_diffs.empty?
      diffs << SecurityGroupDiff.inbound(aws, self, inbound_diffs)
    end

    outbound_diffs = diff_rules(@outbound, aws.ip_permissions_egress, sg_ids_to_names)
    if !outbound_diffs.empty?
      diffs << SecurityGroupDiff.outbound(aws, self, outbound_diffs)
    end

    diffs
  end

  private

  # Internal: Determine changes in rules
  #
  # local_rules     - the rules defined locally
  # aws_rules       - the rules in AWS
  # sg_ids_to_names - a mapping of security group ids to their names
  #
  # Returns an array of RuleDiffs that represent differences between local and AWS configuration
  def diff_rules(local_rules, aws_rules, sg_ids_to_names)
    diffs = []

    # get the aws config into a format that mirrors cumulus so we can compare
    aws = aws_rules.map do |rule|
      RuleConfig.from_aws(rule, sg_ids_to_names)
    end
    aws_hashes = aws.map(&:hash)
    local_hashes = local_rules.map(&:hash)

    diffs << local_rules.reject { |i| aws_hashes.include?(i.hash) }.map { |l| RuleDiff.added(l) }
    diffs << aws.reject { |a| local_hashes.include?(a.hash) }.map { |a| RuleDiff.removed(a) }

    diffs.flatten
  end
end
