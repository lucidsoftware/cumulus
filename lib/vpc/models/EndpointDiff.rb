require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to the endpoint
    module EndpointChange
      include Common::DiffChange

      POLICY = Common::DiffChange.next_change_id
      ROUTE = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class EndpointDiff < Common::Diff
      include EndpointChange

      attr_accessor :route_tables
      attr_accessor :policy_changes

      def self.route_tables(aws, local)
        changes = Common::ListChange.simple_list_diff(aws, local)
        if changes
          diff = EndpointDiff.new(ROUTE, aws, local)
          diff.route_tables = changes
          diff
        end
      end

      PolicyChange = Struct.new(:aws, :local)
      def self.policy(aws, local)
        changes = {}

        aws.each do |k, v|
          if local[k] != v
            changes[k] = PolicyChange.new(v, local[k])
          end
        end

        if !changes.empty?
          diff = EndpointDiff.new(POLICY, aws, local)
          diff.policy_changes = changes
          diff
        end
      end

      def asset_type
        "Endpoint"
      end

      def aws_name
        @aws.service_name
      end

      def diff_string
        case @type
        when POLICY
          [
            "Policy:",
            @policy_changes.map do |k, v|
              [
                "\t#{k}:",
                Colors.aws_changes("#{v.aws}"),
                "->",
                Colors.local_changes("#{v.local}"),
              ].join(" ")
            end
          ].flatten.join("\n")
        when ROUTE
          [
            "Route Tables:",
            @route_tables.removed.map { |d| Colors.unmanaged("\t#{d}") },
            @route_tables.added.map { |d| Colors.added("\t#{d}") },
          ].flatten.join("\n")
        end
      end
    end
  end
end
