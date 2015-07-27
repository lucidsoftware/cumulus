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

    RuleConfig.new({
      "security-group" => security_group,
      "protocol" => aws.ip_protocol,
      "from-port" => aws.from_port,
      "to-port" => aws.to_port,
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

  # Public: Constructor
  #
  # json - a hash containing the JSON configuration for the security group
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
