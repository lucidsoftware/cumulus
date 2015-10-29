require "conf/Configuration"
require "ec2/models/InterfaceDiff"

require "json"

module Cumulus
  module EC2

    # Public: An object representing configuration for a network interface
    class InterfaceConfig
      attr_reader :name
      attr_reader :subnet
      attr_reader :groups
      attr_reader :description
      attr_reader :source_dest_check

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the group
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @subnet = json["subnet"]
          @groups = json["groups"] || []
          @description = json["description"]
          @source_dest_check = json["source-dest-check"]
        end
      end

      def to_hash
        {
          "subnet" => @subnet,
          "groups" => @groups,
          "description" => @description,
          "source-dest-check" => @source_dest_check
        }
      end

      # Public: Populate a config object with AWS configuration
      #
      # aws - the network interface from AWS
      def populate!(aws)
        @subnet = EC2::id_subnets[aws.subnet_id].name || aws.subnet_id
        @groups = aws.groups.map(&:group_name).sort
        @description = aws.description
        @source_dest_check = aws.source_dest_check

        self
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the InterfaceDiffs that were found
      def diff(aws)
        diffs = []

        if @subnet != aws.subnet
          diffs << InterfaceDiff.new(InterfaceChange::SUBNET, aws.subnet, @subnet)
        end

        if @groups.sort != aws.groups.sort
          diffs << InterfaceDiff.groups(aws.groups, @groups)
        end

        if @description != aws.description
          diffs << InterfaceDiff.new(InterfaceChange::DESCRIPTION, aws.description, @description)
        end

        if @source_dest_check != aws.source_dest_check
          diffs << InterfaceDiff.new(InterfaceChange::SDCHECK, aws.source_dest_check, @source_dest_check)
        end

        diffs
      end

    end
  end
end
