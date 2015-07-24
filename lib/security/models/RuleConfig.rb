# Public: An object representing configuration for a security group rule
class RuleConfig

  attr_reader :from
  attr_reader :protocol
  attr_reader :security_group
  attr_reader :to

  # Public: Static method that will produce a RuleConfig from an AWS rule resource.
  #
  # aws - the aws resource to use
  # sg_ids_to_names - a mapping of security group ids to their names
  #
  # Returns a RuleConfig containing the data in the AWS rule
  def RuleConfig.from_aws(aws, sg_ids_to_names)
    security_group = aws.user_id_group_pairs
    if security_group.size == 1
      security_group = sg_ids_to_names[security_group[0].group_id]
    else
      security_group = security_group.map { |s| sg_ids_to_names[s.group_id] }
    end

    RuleConfig.new({
      "security-group" => security_group,
      "protocol" => aws.ip_protocol,
      "from-port" => aws.from_port,
      "to-port" => aws.to_port
    })
  end

  # Public: Constructor
  #
  # json - a hash containing the JSON configuration for the security group
  def initialize(json)
    @from = json["from-port"]
    @protocol = json["protocol"]
    @security_group = json["security-group"]
    @to = json["to-port"]
  end

  # Public: Get the configuration as a hash
  #
  # Returns the hash
  def hash
    {
      "security-group" => @security_group,
      "protocol" => @protocol,
      "from-port" => @from,
      "to-port" => @to
    }.reject { |k, v| v.nil? }
  end

end
