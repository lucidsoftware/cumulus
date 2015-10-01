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
          @network_acls = json["network-acls"] || []
          @subnets = json["subnets"] || []
          @tags = json["tags"] || {}
        end
      end

      def to_hash
        {
          "cidr-block" => @cidr_block,
          "tenancy" => @tenancy,
          "dhcp" => if @dhcp then @dhcp.to_hash end,
          "route-tables" => @route_tables,
          "endpoints" => @endpoints.map(&:to_hash),
          "address-associations" => @address_associations,
          "network-acls" => @network_acls,
          "subnets" => @subnets,
          "tags" => @tags,
        }
      end

      # Public: Populate a config object with AWS configuration
      #
      # aws - the AWS configuration for the subnet
      # route_table_map - an optional mapping of route table ids to names
      # subnet_map - an optional mapping of subnet ids to names
      # network_acl_map - an optional mapping of network acl ids to names
      def populate!(aws, route_table_map = {}, subnet_map = {}, network_acl_map = {})
        @cidr_block = aws.cidr_block
        @tenancy = aws.instance_tenancy

        aws_dhcp = EC2::id_dhcp_options[aws.dhcp_options_id]
        @dhcp = DhcpConfig.new().populate!(aws_dhcp)

        aws_rts = EC2::vpc_route_tables[aws.vpc_id]
        rt_names = aws_rts.map { |rt| route_table_map[rt.route_table_id] || rt.route_table_id }
        @route_tables = rt_names.sort

        aws_endpoints = EC2::vpc_endpoints[aws.vpc_id]
        @endpoints = aws_endpoints.map { |endpoint| EndpointConfig.new().populate!(endpoint, route_table_map) }

        aws_addresses = EC2::vpc_addresses[aws.vpc_id]
        @address_associations = Hash[aws_addresses.map do |addr|
          network_interface = EC2::id_network_interfaces[addr.network_interface_id]
          [addr.public_ip, network_interface.name || addr.network_interface_id]
        end]

        aws_network_acls = EC2::vpc_network_acls[aws.vpc_id]
        cumulus_network_acls = aws_network_acls.map { |acl| network_acl_map[acl.network_acl_id] || acl.network_acl_id }
        @network_acls = cumulus_network_acls.sort

        aws_subnets = EC2::vpc_subnets[aws.vpc_id]
        subnet_names = aws_subnets.map { |subnet| subnet_map[subnet.subnet_id] || subnet.subnet_id }
        @subnets = subnet_names.sort

        @tags = Hash[aws.tags.map { |tag| [tag.key, tag.value] }]

        self
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
        dhcp_diff = VpcDiff.dhcp(aws_dhcp_options, @dhcp)
        if dhcp_diff
          diffs << dhcp_diff
        end

        # Load the actual route table configs to diff them
        local_route_tables = @route_tables.map { |rt_name| Loader.route_table(rt_name) }
        aws_route_tables = EC2::vpc_route_tables[aws.vpc_id]
        route_table_diff = VpcDiff.route_tables(aws_route_tables, local_route_tables)
        if route_table_diff
          diffs << route_table_diff
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
        local_network_acls = @network_acls.map { |acl_name| Loader.network_acl(acl_name) }
        aws_network_acls = EC2::vpc_network_acls[aws.vpc_id]
        network_acl_diff = VpcDiff.network_acls(aws_network_acls, local_network_acls)
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
