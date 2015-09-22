require "common/models/Diff"
require "common/models/TagsDiff"
require "common/models/ListChange"
require "vpc/models/RouteDiff"
require "util/Colors"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to a route table
    module RouteTableChange
      include Common::DiffChange

      ROUTES = Common::DiffChange.next_change_id
      VGWS = Common::DiffChange.next_change_id
      TAGS = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class RouteTableDiff < Common::Diff
      include RouteTableChange
      include Common::TagsDiff

      attr_accessor :routes
      attr_accessor :vgws

      def self.routes(aws, local)
        aws_cidr_routes = Hash[aws.map { |route| [route.destination_cidr_block, route] }]
        local_cidr_routes = Hash[local.map { |route| [route.dest_cidr, route] }]

        added = local_cidr_routes.reject { |k, v| aws_cidr_routes.has_key? k }
        removed = aws_cidr_routes.reject { |k, v| local_cidr_routes.has_key? k }
        modified = local_cidr_routes.select { |k, v| aws_cidr_routes.has_key? k }

        added_diffs = Hash[added.map { |cidr, route| [cidr, RouteDiff.added(route)] }]
        removed_diffs = Hash[removed.map { |cidr, route| [cidr, RouteDiff.unmanaged(route)] }]
        modified_diffs = Hash[modified.map { |cidr, route | [cidr, route.diff(aws_cidr_routes[cidr])] }].reject { |k, v| v.empty? }

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = RouteTableDiff.new(ROUTES, aws, local)
          diff.routes = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      def self.propagate_vgws(aws, local)
        changes = Common::ListChange.simple_list_diff(aws, local)
        if changes
          diff = RouteTableDiff.new(VGWS, aws, local)
          diff.vgws = changes
          diff
        end
      end

      def local_tags
        @local
      end

      def aws_tags
        @aws
      end

      def asset_type
        "Route Table"
      end

      def aws_name
        @aws.name
      end

      def diff_string
        case @type
        when ROUTES
          [
            "Routes:",
            @routes.removed.map { |s, _| Colors.unmanaged("\t#{s} will be deleted") },
            @routes.added.map { |s, _| Colors.added("\t#{s} will be created") },
            @routes.modified.map do |cidr, diffs|
              [
                "\t#{cidr}:",
                diffs.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        when VGWS
          [
            "Propagate VGWs:",
            @vgws.removed.map { |s, _| Colors.unmanaged("\t#{s}") },
            @vgws.added.map { |s, _| Colors.added("\t#{s}") },
          ].flatten.join("\n")
        when TAGS
          tags_diff_string
        end
      end
    end
  end
end
