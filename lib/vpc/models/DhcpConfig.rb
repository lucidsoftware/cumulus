require "conf/Configuration"
require "vpc/models/DhcpDiff"

require "json"

module Cumulus
  module VPC

    # Public: An object representing configuration for a VPC's dhcp options
    class DhcpConfig
      attr_reader :domain_name_servers
      attr_reader :domain_name
      attr_reader :ntp_servers
      attr_reader :netbios_name_servers
      attr_reader :netbios_node_type

      require "aws_extensions/ec2/DhcpOptions"
      Aws::EC2::Types::DhcpOptions.send(:include, AwsExtensions::EC2::DhcpOptions)

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the dhcp options
      def initialize(json = nil)
        if !json.nil?
          @domain_name_servers = json["domain-name-servers"] || []
          @domain_name = json["domain-name"]
          @ntp_servers = json["ntp-servers"] || []
          @netbios_name_servers = json["netbios-name-servers"] || []
          @netbios_node_type = json["netbios-node-type"]
        end
      end

      def to_hash
        {
          "domain-name-servers" => @domain_name_servers,
          "domain-name" => @domain_name,
          "ntp-servers" => @ntp_servers,
          "netbios-name-servers" => @netbios_name_servers,
          "netbios-node-type" => @netbios_node_type,
        }.reject { |k, v| v.nil? or v.empty? }
      end

      def to_aws
        to_hash.map do |key, value|
          {
            key: key,
            values: [value].flatten
          }
        end
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the DhcpDiffs that were found
      def diff(aws)
        diffs = []

        if @domain_name_servers.sort != aws.domain_name_servers.sort
          domain_servers_diff = DhcpDiff.domain_servers(aws.domain_name_servers, @domain_name_servers)
          diffs << domain_servers_diff if domain_servers_diff
        end

        if @domain_name != aws.domain_name
          diffs << DhcpDiff.new(DhcpChange::DOMAIN_NAME, aws.domain_name, @domain_name)
        end

        if @ntp_servers.sort != aws.ntp_servers.sort
          ntp_diff = DhcpDiff.ntp_servers(aws.ntp_servers, @ntp_servers)
          diffs << ntp_diff if ntp_diff
        end

        if @netbios_name_servers.sort != aws.netbios_name_servers.sort
          netbios_diff = DhcpDiff.netbios_servers(aws.netbios_name_servers, @netbios_name_servers)
          diffs << netbios_diff if netbios_diff
        end

        if @netbios_node_type != aws.netbios_node_type
          diffs << DhcpDiff.new(DhcpChange::NETBIOS_NODE, aws.netbios_node_type, @netbios_node_type)
        end

        diffs
      end

    end
  end
end
