require "security/loader/Loader"

# Public: An object representing configuration for a security group rule
class RuleConfig

  attr_reader :from
  attr_reader :protocol
  attr_reader :security_group
  attr_reader :subnets
  attr_reader :to

  # Public: Static method that will produce a RuleConfig from an AWS rule resource.
  #
  # aws - the aws resource to use
  # sg_ids_to_names - a mapping of security group ids to their names
  #
  # Returns a RuleConfig containing the data in the AWS rule
  def RuleConfig.from_aws(aws, sg_ids_to_names)
    security_group = if aws.user_id_group_pairs.size == 1
      sg_ids_to_names[aws.user_id_group_pairs[0].group_id]
    else
      nil
    end

    subnets = if aws.ip_ranges.empty?
      nil
    else
      aws.ip_ranges.map { |ip| ip.cidr_ip }
    end

    from_port = aws.from_port
    to_port = aws.to_port
    if from_port == -1 or to_port == -1
      from_port = nil
      to_port = nil
    end

    RuleConfig.new({
      "security-group" => security_group,
      "protocol" => aws.ip_protocol,
      "from-port" => from_port,
      "to-port" => to_port,
      "subnets" => subnets
    })
  end

  # Public: Static method that will produce a RuleConfig that allows all access
  #
  # Returns the RuleConfig
  def RuleConfig.allow_all
    RuleConfig.new({
      "protocol" => "all",
      "subnets" => ["0.0.0.0/0"]
    })
  end

  # Public: Static method that will produce multiple RuleConfigs, one for each port
  # range.
  #
  # json - a hash containing the JSON configuration for the rule
  #
  # Returns an array of RuleConfigs
  def RuleConfig.expand_ports(json)
    ports = json["ports"]

    if !ports.nil?
      ports.map do |port|
        rule_hash = json.clone

        if port.is_a? String
          parts = port.split("-").map(&:strip)
          rule_hash["from-port"] = parts[0].to_i
          rule_hash["to-port"] = parts[1].to_i
        else
          rule_hash["from-port"] = port
          rule_hash["to-port"] = port
        end

        RuleConfig.expand_security_groups(rule_hash)
      end.flatten
    else
      RuleConfig.expand_security_groups(json)
    end
  end

  # Public: Static method that will produce multiple RuleConfigs, one for each security
  # group in the json object passed in.
  #
  # json - a hash containing JSON configuration for the rule
  #
  # Returns an array of RuleConfigs
  def RuleConfig.expand_security_groups(json)
    security_groups = json["security-groups"]

    if !security_groups.nil?
      security_groups.map do |security_group|
        rule_hash = json.clone
        rule_hash["security-group"] = security_group
        RuleConfig.new(rule_hash)
      end
    else
      RuleConfig.new(json)
    end
  end

  # Public: Constructor
  #
  # json - a hash containing the JSON configuration for the rule
  def initialize(json)
    @from = json["from-port"]
    @protocol = json["protocol"]
    @to = json["to-port"]
    if !json["security-group"].nil?
      @security_group = json["security-group"]
    end
    if !json["subnets"].nil?
      @subnets = json["subnets"].map do |subnet|
        if subnet.match(/\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}\/\d+/).nil?
          Loader.subnet_group(subnet)
        else
          subnet
        end
      end.flatten
    end
  end

  # Public: Get the protocol. If "all" was specified in the configuration,
  # "-1" will be returned, which is what AWS uses to specify all.
  #
  # Returns the protocol
  def protocol
    if @protocol == "all" then "-1" else @protocol end
  end

  # Public: Get the configuration as a hash
  #
  # Returns the hash
  def hash
    {
      "security-group" => @security_group,
      "protocol" => protocol,
      "from-port" => @from,
      "to-port" => @to,
      "subnets" => @subnets,
    }.reject { |k, v| v.nil? }
  end

end
