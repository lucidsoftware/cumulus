# A class used to migrate RuleConfigs
class RuleMigration

  attr_reader :ports
  attr_reader :protocol
  attr_reader :security_groups
  attr_reader :subnets

  # Public: Static method that will produce a RuleMigration from a RuleConfig
  #
  # rule_config - the RuleConfig to create from
  #
  # Returns the corresponding RuleMigration
  def self.from_rule_config(rule_config)
    ports = if rule_config.from.nil? and rule_config.to.nil?
      nil
    else
      if rule_config.from == rule_config.to
        [rule_config.from]
      else
        ["#{rule_config.from}-#{rule_config.to}"]
      end
    end

    security_groups = if !rule_config.security_group.nil?
      [rule_config.security_group]
    else
      nil
    end

    # we're gonna replace any "0.0.0.0/0" with all to educate users on subnets.json
    subnets = if !rule_config.subnets.nil?
      rule_config.subnets.map do |subnet|
        if subnet == "0.0.0.0/0"
          "all"
        else
          subnet
        end
      end
    else
      nil
    end

    RuleMigration.new(
      ports,
      rule_config.protocol,
      security_groups,
      subnets
    )
  end

  # Public: Constructor.
  #
  # ports           - an array of the ports to put into cumulus config, or nil for all
  # protocol        - the protocol for the rule
  # security_groups - an array of security group names for the rule, or nil if there are no security groups
  # subnets         - an array of subnets to include in the rule, or nil if there are no subnets
  def initialize(ports, protocol, security_groups, subnets)
    @ports = ports
    @protocol = protocol
    @security_groups = security_groups
    @subnets = subnets
  end

  # Public: Get the configuration as a hash for migration
  #
  # Returns the hash
  def hash
    {
      "security-groups" => @security_groups,
      "protocol" => @protocol,
      "ports" => @ports,
      "subnets" => @subnets,
    }.reject { |k, v| v.nil? }
  end

  # Public: Combine two RuleMigrations by combining allowed entities (security group or subnet).
  #
  # other - the other RuleMigration to combine with this one
  #
  # Returns the a new RuleMigration with this RuleMigration's ports and protocol, and
  # the allowed entities of both RuleMigrations concatenated together
  def combine_allowed(other)
    if !@security_groups.nil?
      RuleMigration.new(
        @ports,
        @protocol,
        @security_groups + other.security_groups,
        @subnets
      )
    else
      RuleMigration.new(
        @ports,
        @protocol,
        @security_groups,
        @subnets + other.subnets
      )
    end
  end

  # Public: Combine two RuleMigrations by combining ports. If both of the RuleMigrations
  # have nil ports, they will be combined, but if only one does, an array containing
  # both RuleMigrations (unchanged) will be returned
  #
  # other - the other RuleMigration to combine with this one
  #
  # Returns a new RuleMigration with this RuleMigration's allowed entities and the combined port
  # or an array of the two original RuleMigrations
  def combine_ports(other)
    # In this case, they should be identical, we just return self
    if @ports.nil? and other.ports.nil?
      self
    # at this point we're guaranteed that if one of the ports is nil, the other is not
    elsif @ports.nil? or other.ports.nil?
      [self, other]
    else
      RuleMigration.new(
        @ports + other.ports,
        @protocol,
        @security_groups,
        @subnets
      )
    end
  end
end
