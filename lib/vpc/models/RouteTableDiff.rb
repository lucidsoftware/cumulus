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

      def self.routes(aws, local)
        aws_cidr_routes = Hash[aws.map { |route| [route.destination_cidr_block, route] }]
        local_cidr_routes = Hash[local.map { |route| [route.dest_cidr, route] }]

        added = local_cidr_routes.reject { |k, v| aws_cidr_routes.has_key? k }
        removed = aws_cidr_routes.reject { |k, v| local_cidr_routes.has_key? k }
        modified = local_cidr_routes.select { |k, v| aws_cidr_routes.has_key? k }

        added_diffs = Hash[added.map { |cidr, route| [cidr, RouteDiff.added(route)] }]
        removed_diffs = Hash[removed.map { |cidr, route| [cidr, RouteDiff.unmanaged(route)] }]
        modified_diffs = Hash[modified.map do |cidr, route|
          aws_route = aws_cidr_routes[cidr]
          route_diffs = route.diff(aws_route)
          if !route_diffs.empty?
            [cidr, RouteDiff.modified(aws_route, route, route_diffs)]
          end
        end.reject { |v| v.nil? }]

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = RouteTableDiff.new(ROUTES, aws, local)
          diff.changes = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      def self.propagate_vgws(aws, local)
        changes = Common::ListChange.simple_list_diff(aws, local)
        if changes
          diff = RouteTableDiff.new(VGWS, aws, local)
          diff.changes = changes
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
            @changes.removed.map { |s, _| Colors.unmanaged("\t#{s} will be deleted") },
            @changes.added.map { |s, _| Colors.added("\t#{s} will be created") },
            @changes.modified.map do |cidr, diff|
              [
                "\t#{cidr}:",
                diff.changes.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        when VGWS
          [
            "Propagate VGWs:",
            @changes.removed.map { |s, _| Colors.unmanaged("\t#{s}") },
            @changes.added.map { |s, _| Colors.added("\t#{s}") },
          ].flatten.join("\n")
        when TAGS
          tags_diff_string
        end
      end
    end
  end
end
