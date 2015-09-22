require "conf/Configuration"
require "vpc/loader/Loader"
require "vpc/models/DhcpConfig"
require "vpc/models/RouteTableConfig"
require "vpc/models/EndpointConfig"
require "vpc/models/NetworkAclConfig"
require "vpc/models/VpcDiff"
require "ec2/EC2"

require "json"

module Cumulus
  module VPC

    # Public: An object representing configuration for a VPC
    class VpcConfig
      attr_reader :name
      attr_reader :cidr_block
      attr_reader :tenancy
      attr_reader :subnets
      attr_reader :dhcp
      attr_reader :route_tables
      attr_reader :endpoints
      attr_reader :address_associations
      attr_reader :network_acls
      attr_reader :tags

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the VPC
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @cidr_block = json["cidr-block"]
          @tenancy = json["tenancy"]
          @dhcp = if json["dhcp"] then DhcpConfig.new(json["dhcp"]) end
          @route_tables = json["route-tables"] || []
          @endpoints = (json["endpoints"] || []).map { |endpoint| EndpointConfig.new(endpoint) }
          @address_associations = json["address-associations"] || {}
          @network_acls = (json["network-acls"] || []).map { |acl| NetworkAclConfig.new(acl) }
          @subnets = json["subnets"] || []
          @tags = json["tags"] || {}
        end
      end

      # Public: Get the config as a prettified JSON string.
      #
      # Returns the JSON string
      def pretty_json
        JSON.pretty_generate({
          "cidr-block" => @cidr_block,
          "tenancy" => @tenancy,
          "dhcp" => if @dhcp then @dhcp.to_hash end,
          "route-tables" => @route_tables,
          "endpoints" => @endpoints.map(&:to_hash),
          "address-associations" => @address_associations,
          "network-acls" => @network_acls.map(&:to_hash),
          "subnets" => @subnets,
          "tags" => @tags,
        })
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the VpcDiffs that were found
      def diff(aws)
        diffs = []

        if @cidr_block != aws.cidr_block
          diffs << VpcDiff.new(VpcChange::CIDR, aws.cidr_block, @cidr_block)
        end

        if @tenancy != aws.instance_tenancy
          diffs << VpcDiff.new(VpcChange::TENANCY, aws.instance_tenancy, @tenancy)
        end

        # Get the actual DHCP Options from AWS from the id
        aws_dhcp_options = EC2::id_dhcp_options[aws.dhcp_options_id]
        dhcp_diffs = @dhcp.diff(aws_dhcp_options)
        if !dhcp_diffs.empty?
          diffs << VpcDiff.dhcp(dhcp_diffs, aws_dhcp_options, @dhcp)
        end

        # Load the actual route table configs to diff them
        local_route_tables = @route_tables.map { |rt_name| Loader.route_table(rt_name) }
        aws_route_tables = EC2::vpc_route_tables[aws.vpc_id]
        route_table_diffs = VpcDiff.route_tables(aws_route_tables, local_route_tables)
        if route_table_diffs
          diffs << route_table_diffs
        end

        # Load the vpc endpoints
        aws_endpoints = EC2::vpc_endpoints[aws.vpc_id]
        endpoints_diff = VpcDiff.endpoints(aws_endpoints, @endpoints)
        if endpoints_diff
          diffs << endpoints_diff
        end

        aws_associations = EC2::vpc_addresses[aws.vpc_id]
        association_diff = VpcDiff.address_associations(aws_associations, @address_associations)
        if association_diff
          diffs << association_diff
        end

        # Inbound and outbound network acls
        aws_network_acls = EC2::vpc_network_acls[aws.vpc_id]
        network_acl_diff = VpcDiff.network_acls(aws_network_acls, @network_acls)
        if network_acl_diff
          diffs << network_acl_diff
        end

        # Load the local subnets from config, and the aws version of their subnets
        local_subnets = @subnets.map { |subnet_name| Loader.subnet(subnet_name) }
        aws_subnets = EC2::vpc_subnets[aws.vpc_id]
        subnets_diff = VpcDiff.subnets(aws_subnets, local_subnets)
        if subnets_diff
          diffs << subnets_diff
        end

        # Tags
        aws_tags = Hash[aws.tags.map { |tag| [tag.key, tag.value] }]
        if @tags != aws_tags
          diffs << VpcDiff.new(VpcChange::TAGS, aws_tags, @tags)
        end

        diffs
      end

    end
  end
end
