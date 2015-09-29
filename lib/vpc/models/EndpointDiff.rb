require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

require "json"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to the endpoint
    module EndpointChange
      include Common::DiffChange

      POLICY = Common::DiffChange.next_change_id
      ROUTE_TABLES = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class EndpointDiff < Common::Diff
      include EndpointChange

      def self.route_tables(aws, local)
        changes = Common::ListChange.simple_list_diff(aws, local)
        if changes
          diff = EndpointDiff.new(ROUTE_TABLES, aws, local)
          diff.changes = changes
          diff
        end
      end

      def self.policy(aws, local)
        if aws != local
          diff = EndpointDiff.new(POLICY, aws, local)
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
            "Policy Statement:",
            Colors.unmanaged([
              "\tRemoving:",
              JSON.pretty_generate(aws).lines.map { |l| "\t\t#{l}".chomp("\n") }
            ].join("\n")),
            Colors.added([
              "\tAdding:",
              JSON.pretty_generate(local).lines.map { |l| "\t\t#{l}".chomp("\n") }
            ].join("\n"))
          ].join("\n")
        when ROUTE_TABLES
          [
            "Route Tables:",
            @changes.removed.map { |d| Colors.unmanaged("\t#{d}") },
            @changes.added.map { |d| Colors.added("\t#{d}") },
          ].flatten.join("\n")
        end
      end
    end
  end
end
