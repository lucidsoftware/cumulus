require "conf/Configuration"
require "vpc/loader/Loader"
require "ec2/EC2"

require "json"
require "uri"

module Cumulus
  module VPC

    # Public: An object representing configuration for a VPC endpoint
    class EndpointConfig
      attr_reader :service_name
      attr_reader :policy
      attr_reader :route_tables

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the endpoint
      def initialize(json = nil)
        if !json.nil?
          @service_name = json["service-name"]
          @policy = json["policy"]
          @route_tables = json["route-tables"] || []
        end
      end

      def to_hash
        {
          "service-name" => @service_name,
          "policy" => @policy,
          "route-tables" => @route_tables,
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the EndpointDiffs that were found
      def diff(aws)
        diffs = []

        # policy aws.policy_document
        aws_policy_statement = JSON.parse(URI.decode(aws.policy_document))["Statement"].first
        local_policy_statement = Loader.policy(@policy)["Statement"].first
        policy_diff = EndpointDiff.policy(aws_policy_statement, local_policy_statement)

        if policy_diff
          diffs << policy_diff
        end

        # routes
        aws_rts = aws.route_table_ids.map { |rt_id| EC2::id_route_tables[rt_id] }
        aws_rt_names = aws_rts.map { |rt| rt.name || rt.route_table_id }

        rt_diff = EndpointDiff.route_tables(aws_rt_names, @route_tables)
        if rt_diff
          diffs << rt_diff
        end

        diffs
      end

    end
  end
end
