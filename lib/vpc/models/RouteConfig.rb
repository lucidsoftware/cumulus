require "conf/Configuration"
require "vpc/loader/Loader"
require "ec2/EC2"

require "json"

module Cumulus
  module VPC

    # Public: An object representing configuration for a VPC route table route
    class RouteConfig
      attr_reader :dest_cidr
      attr_reader :gateway_id
      attr_reader :instance_id
      attr_reader :network_interface_id
      attr_reader :vpc_peering_connection_id

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the route table route
      def initialize(json = nil)
        if !json.nil?
          @dest_cidr = json["dest-cidr"]
          @gateway_id = json["gateway-id"]
          @network_interface_id = json["network-interface-id"]
          @vpc_peering_connection_id = json["vpc-peering-connection-id"]
        end
      end

      def to_hash
        {
          "dest-cidr" => @dest_cidr,
          "gateway-id" => @gateway_id,
          "network-interface-id" => @network_interface_id,
          "vpc-peering-connection-id" => @vpc_peering_connection_id,
        }.reject { |k, v| v.nil? }
      end

      def populate!(aws)
        @dest_cidr = aws.destination_cidr_block
        @gateway_id = aws.gateway_id
        @network_interface_id = aws.network_interface_id
        @vpc_peering_connection_id = aws.vpc_peering_connection_id

        self
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the RouteDiffs that were found
      def diff(aws)
        diffs = []

        if @gateway_id != aws.gateway_id
          diffs << RouteDiff.new(RouteChange::GATEWAY, aws.gateway_id, @gateway_id)
        end

        if @network_interface_id != aws.network_interface_id
          diffs << RouteDiff.new(RouteChange::NETWORK, aws.network_interface_id, @network_interface_id)
        end

        if @vpc_peering_connection_id != aws.vpc_peering_connection_id
          diffs << RouteDiff.new(RouteChange::VPC_PEERING, aws.vpc_peering_connection_id, @vpc_peering_connection_id)
        end

        diffs
      end

    end
  end
end
