require "conf/Configuration"
require "vpc/models/AclEntryDiff"
require "ec2/IPProtocolMapping"

module Cumulus
  module VPC

    # Public: An object representing configuration for a VPC Network ACL Entry
    class AclEntryConfig
      attr_reader :rule
      attr_reader :protocol
      attr_reader :action
      attr_reader :cidr_block
      attr_reader :ports
      attr_reader :icmp_type
      attr_reader :icmp_code

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the entry
      def initialize(json = nil)
        if !json.nil?
          @rule = json["rule"]
          @protocol = json["protocol"].upcase
          @action = json["action"]
          @cidr_block = json["cidr-block"]
          @ports = json["ports"]
          @icmp_type = json["icmp-type"]
          @icmp_code = json["icmp-code"]
        end
      end

      def to_hash
        {
          "rule" => @rule,
          "protocol" => @protocol,
          "action" => @action,
          "cidr-block" => @cidr_block,
          "ports" => @ports,
          "icmp-type" => @icmp_type,
          "icmp-code" => @icmp_code,
        }.reject { |k, v| v.nil? }
      end

      def populate!(aws)
        @rule = aws.rule_number
        @protocol = EC2::IPProtocolMapping.keyword(aws.protocol)
        @action = aws.rule_action
        @cidr_block = aws.cidr_block

        aws_from_port = aws.port_range.from if aws.port_range
        aws_to_port = aws.port_range.to if aws.port_range

        if aws_from_port
          if aws_from_port == aws_to_port
            @ports = aws_from_port.to_i
          else
            @ports = "#{aws_from_port}-#{aws_to_port}"
          end
        end

        aws_icmp_type = aws.icmp_type_code.type if aws.icmp_type_code
        if aws_icmp_type
          @icmp_type = aws_icmp_type
        end

        aws_icmp_code = aws.icmp_type_code.code if aws.icmp_type_code
        if aws_icmp_code
          @icmp_code = aws_icmp_code
        end

        self
      end

      # Public: expands the ports string into a from and to port
      #
      # Returns the from port and to port as Integer
      def expand_ports
        # Get the local port values as integers
        local_from_port = nil
        local_to_port = nil

        if @ports.is_a? String
          parts = @ports.split("-").map(&:strip)
          local_from_port = parts[0].to_i
          local_to_port = parts[1].to_i
        elsif @ports.is_a? Integer
          local_from_port = port
          local_to_port = port
        end

        return local_from_port, local_to_port
      end

      # Public: creates a string representation of the entry
      # for printing in the console. Not in JSON format
      def pretty_string
        [
          "Rule:\t\t#{rule}",
          "Protocol:\t#{protocol}",
          "Action:\t\t#{action}",
          "CIDR Block:\t#{cidr_block}",
          if ports then "Ports:\t\t#{ports}" end,
          if icmp_type then "ICMP Type:\t#{icmp_type}" end,
          if icmp_code then "ICMP Code:\t#{icmp_code}" end,
        ].reject(&:nil?).join("\n")
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource populated in an AclEntryConfig
      #
      # Returns an array of the AclEntryDiffs that were found
      def diff(aws)
        diffs = []

        if @protocol != aws.protocol
          diffs << AclEntryDiff.new(AclEntryChange::PROTOCOL, aws.protocol, @protocol)
        end

        if @action != aws.action
          diffs << AclEntryDiff.new(AclEntryChange::ACTION, aws.action, @action)
        end

        if @cidr_block != aws.cidr_block
          diffs << AclEntryDiff.new(AclEntryChange::CIDR, aws.cidr_block, @cidr_block)
        end

        local_from_port, local_to_port = expand_ports
        aws_from_port, aws_to_port = aws.expand_ports

        if local_from_port != aws_from_port or local_to_port != aws_to_port
          diffs << AclEntryDiff.new(AclEntryChange::PORTS, aws.ports, @ports)
        end

        if @icmp_type != aws.icmp_type
          diffs << AclEntryDiff.new(AclEntryChange::ICMP_TYPE, aws.icmp_type, @icmp_type)
        end

        if @icmp_code != aws.icmp_code
          diffs << AclEntryDiff.new(AclEntryChange::ICMP_CODE, aws.icmp_code, @icmp_code)
        end

        diffs
      end

    end
  end
end
