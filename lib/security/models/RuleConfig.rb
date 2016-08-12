require "security/loader/Loader"
require "security/SecurityGroups"

module Cumulus
  module SecurityGroups
    # Public: An object representing configuration for a security group rule
    class RuleConfig

      attr_reader :from
      attr_reader :protocol
      attr_reader :security_groups
      attr_reader :subnets
      attr_reader :to

      # Public: Static method that will produce a RuleConfig from an AWS rule resource.
      #
      # aws - the aws resource to use
      #
      # Returns a RuleConfig containing the data in the AWS rule
      def RuleConfig.from_aws(aws)
        RuleConfig.new({
          "security-groups" => aws.user_id_group_pairs.map { |security| SecurityGroups::id_security_groups[security.group_id].group_name },
          "protocol" => if aws.ip_protocol == "-1" then "all" else aws.ip_protocol end,
          "from-port" => if aws.ip_protocol != "icmp" and aws.from_port != -1 then aws.from_port end,
          "to-port" => if aws.ip_protocol != "icmp" and aws.to_port != -1 then aws.to_port end,
          "icmp-type" => if aws.ip_protocol == "icmp"
            if aws.from_port != -1 then aws.from_port else "all" end
          end,
          "icmp-code" => if aws.ip_protocol == "icmp"
            if aws.to_port != -1 then aws.to_port  else "all" end
          end,
          "subnets" => aws.ip_ranges.map { |ip| ip.cidr_ip },
        }.reject { |k, v| v.nil? })
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
              if port.downcase == "all"
                rule_hash["from-port"] = nil
                rule_hash["to-port"] = nil
              else
                parts = port.split("-").map(&:strip)
                rule_hash["from-port"] = parts[0].to_i
                rule_hash["to-port"] = parts[1].to_i
              end
            else
              rule_hash["from-port"] = port
              rule_hash["to-port"] = port
            end

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
        @protocol = json["protocol"]

        if @protocol.downcase == "icmp"
          @from = json["icmp-type"]
          @to = json["icmp-code"]
        else
          @from = json["from-port"]
          @to = json["to-port"]
        end

        @security_groups = if !json["security-groups"].nil? then json["security-groups"] else [] end
        @subnets = if !json["subnets"].nil?
          json["subnets"].flat_map do |subnet|
            if subnet.match(/\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}\/\d+/).nil?
              Loader.subnet_group(subnet)
            else
              subnet
            end
          end.sort
        else
          []
        end
      end

      # Public: Get the configuration as a hash
      #
      # Returns the hash
      def hash
        security_hashes = @security_groups.map do |security_group|
          {
            "security-groups" => [security_group],
            "protocol" => @protocol,
            "from-port" => if @protocol != "icmp" then @from end,
            "to-port" => if @protocol != "icmp" then @to end,
            "subnets" => [],
            "icmp-type" => if @protocol == "icmp" then @from end,
            "icmp-code" => if @protocol == "icmp" then @to end,
          }.reject { |k, v| v.nil? }
        end
        subnet_hashes = @subnets.map do |subnet|
          {
            "security-groups" => [],
            "protocol" => @protocol,
            "from-port" => if @protocol != "icmp" then @from end,
            "to-port" => if @protocol != "icmp" then @to end,
            "subnets" => [subnet],
            "icmp-type" => if @protocol == "icmp" then @from end,
            "icmp-code" => if @protocol == "icmp" then @to end,
          }.reject { |k, v| v.nil? }
        end

        security_hashes + subnet_hashes
      end

      # Public: Converts the RuleConfig into the format needed by AWS
      # to authorize/deauthorize rules
      #
      # vpc_id - the id of the vpc that security group ids should be derived from
      def to_aws(vpc_id)
        {
          ip_protocol: if @protocol == "all" then "-1" else @protocol end,
          from_port: if @from == "all" then "-1" else @from end,
          to_port: if @to == "all" then "-1" else @to end,
          user_id_group_pairs: if !@security_groups.empty?
            @security_groups.map do |sg|
              {
                group_id: SecurityGroups::vpc_security_group_id_names[vpc_id].key(sg)
              }
            end
          end,
          ip_ranges: if !@subnets.empty?
            @subnets.map do |subnet|
              {
                cidr_ip: subnet
              }
            end
          end
        }
      end

    end
  end
end
