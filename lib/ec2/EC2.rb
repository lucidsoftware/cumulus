require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module EC2
    class << self
      @@client = Aws::EC2::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)

      require "aws_extensions/ec2/Subnet"
      Aws::EC2::Types::Subnet.send(:include, AwsExtensions::EC2::Subnet)

      # Public:
      #
      # Returns a map of subnets mapped to their id
      def id_subnets
        @id_subnets ||= Hash[subnets.map { |subnet| [subnet.subnet_id, subnet] }]
      end

      # Public:
      #
      # Returns a map of subnets mapped to the value of the "Name" tag
      def named_subnets
        @named_subnets ||= Hash[subnets.map { |subnet| [subnet.name, subnet] }]
          .reject { |k, v| k.nil? or v.nil? }
      end

      # Public:
      #
      # Returns all subnets as an array of Aws::EC2::Types::Subnet
      def subnets
        @subnets ||= init_subnets
      end

      private

      # Internal: Load all subnets
      #
      # Returns an array of Aws::EC2::Types::Subnet
      def init_subnets
        @@client.describe_subnets.subnets
      end

    end
  end
end
