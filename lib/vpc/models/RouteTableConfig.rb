require "conf/Configuration"
require "vpc/loader/Loader"
require "vpc/models/RouteConfig"
require "ec2/EC2"

require "json"

module Cumulus
  module VPC

    # Public: An object representing configuration for a VPC route table
    class RouteTableConfig
      attr_reader :name
      attr_reader :routes
      attr_reader :propagate_vgws
      attr_reader :tags

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the route table
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @routes = (json["routes"] || []).map { |route| RouteConfig.new(route) }
          @propagate_vgws = json["propagate-vgws"] || []
          @tags = json["tags"]
          @excludes = json["exclude-cidr-blocks"] || []
        end
      end

      def to_hash
        {
          "routes" => @routes.map(&:to_hash),
          "propagate-vgws" => @propagate_vgws,
          "tags" => @tags,
        }.reject { |k, v| v.nil? }
      end

      def populate!(aws)
        @routes = aws.diffable_routes.reject { |route| @excludes.include? route.destination_cidr_block }.map do |aws_route|
          cumulus_route = RouteConfig.new
          cumulus_route.populate!(aws_route)
          cumulus_route
        end

        @propagate_vgws = aws.propagating_vgws.map(&:gateway_id)

        @tags = Hash[aws.tags.map { |tag| [tag.key, tag.value] }]

        self
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the RouteTableDiffs that were found
      def diff(aws)
        diffs = []

        aws_routes = aws.diffable_routes.reject { |route| @excludes.include? route.destination_cidr_block }
        local_routes = @routes.reject { |route| @excludes.include? route.dest_cidr }

        ignored_aws_routes = aws.diffable_routes.select { |route| @excludes.include? route.destination_cidr_block }.map(&:destination_cidr_block).join(", ")
        ignored_local_routes = @routes.select { |route| @excludes.include? route.dest_cidr }.map(&:dest_cidr).join(", ")

        puts "Ignoring local routes: #{ignored_local_routes}" if !ignored_local_routes.empty?
        puts "Ignoring AWS routes: #{ignored_aws_routes}" if !ignored_aws_routes.empty?

        routes_diff = RouteTableDiff.routes(aws_routes, local_routes)
        if routes_diff
          diffs << routes_diff
        end

        aws_vgw_ids = aws.propagating_vgws.map(&:gateway_id)
        if @propagate_vgws.sort != aws_vgw_ids.sort
          diffs << RouteTableDiff.propagate_vgws(aws_vgw_ids, @propagate_vgws)
        end

        aws_tags = Hash[aws.tags.map { |tag| [tag.key, tag.value] }]
        if @tags != aws_tags
          diffs << RouteTableDiff.new(RouteTableChange::TAGS, aws_tags, @tags)
        end

        diffs
      end

    end
  end
end
