require "conf/Configuration"
require "vpc/loader/Loader"
require "vpc/models/SubnetDiff"
require "ec2/EC2"

require "json"

module Cumulus
  module VPC

    # Public: An object representing configuration for a Subnet
    class SubnetConfig
      attr_reader :name
      attr_reader :cidr_block
      attr_reader :map_public_ip
      attr_reader :route_table
      attr_reader :network_acl
      attr_reader :availability_zone
      attr_reader :tags

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the subnet
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @cidr_block = json["cidr-block"]
          @map_public_ip = json["map-public-ip"] || false
          @route_table = json["route-table"]
          @network_acl = json["network-acl"]
          @availability_zone = json["availability-zone"]
          @tags = json["tags"] || {}
        end
      end

      # Public: Get the config as a prettified JSON string.
      #
      # Returns the JSON string
      def pretty_json
        JSON.pretty_generate({
          "cidr-block" => @cidr_block,
          "map-public-ip" => @map_public_ip,
          "route-table" => @route_table,
          "network-acl" => @network_acl,
          "availability-zone" => @availability_zone,
          "tags" => @tags,
        })
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the SubnetDiffs that were found
      def diff(aws)
        diffs = []

        if @cidr_block != aws.cidr_block
          diffs << SubnetDiff.new(SubnetChange::CIDR, aws.cidr_block, @cidr_block)
        end

        if @map_public_ip != aws.map_public_ip_on_launch
          diffs << SubnetDiff.new(SubnetChange::PUBLIC, aws.map_public_ip_on_launch, @map_public_ip)
        end

        # For route table try to get the AWS name or default to id
        aws_subnet_rt = EC2::subnet_route_tables[aws.subnet_id]
        aws_rt_name = if aws_subnet_rt then aws_subnet_rt.name || aws_subnet_rt.route_table_id end
        if @route_table != aws_rt_name
          diffs << SubnetDiff.new(SubnetChange::ROUTE_TABLE, aws_rt_name, @route_table)
        end

        # For network acl try to get the AWS name or default to its id
        aws_subnet_net_acl = EC2::subnet_network_acls[aws.subnet_id]
        aws_net_acl_name = aws_subnet_net_acl.name || aws_subnet_net_acl.network_acl_id
        if @network_acl != aws_net_acl_name
          diffs << SubnetDiff.new(SubnetChange::NETWORK_ACL, aws_net_acl_name, @network_acl)
        end

        if @availability_zone != aws.availability_zone
          diffs << SubnetDiff.new(SubnetChange::AZ, aws.availability_zone, @availability_zone)
        end

        aws_tags = Hash[aws.tags.map { |tag| [tag.key, tag.value] }]
        if @tags != aws_tags
          diffs << SubnetDiff.new(SubnetChange::TAGS, aws_tags, @tags)
        end

        diffs
      end

    end
  end
end
