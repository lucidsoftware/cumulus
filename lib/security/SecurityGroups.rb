require "conf/Configuration"
require "ec2/EC2"

require "aws-sdk"

module Cumulus
  module SecurityGroups
    class << self
      @@client = Aws::EC2::Client.new(Configuration.instance.client)

      require "aws_extensions/ec2/SecurityGroup"
      Aws::EC2::Types::SecurityGroup.send(:include, AwsExtensions::EC2::SecurityGroup)

      def id_security_groups
        @id_security_groups ||= Hash[security_groups.map { |a| [a.group_id, a] }]
      end

      # Public: Returns a Hash of vpc id to Hash of security group name to group
      def vpc_security_groups
        @vpc_security_groups ||= Hash[security_groups.map(&:vpc_id).uniq.map do |vpc_id|
          [vpc_id, Hash[security_groups.select { |g| g.vpc_id == vpc_id }.map { |g| [g.group_name, g] }]]
        end]
      end

      # Describe all security groups
      def security_groups
        @security_groups ||= @@client.describe_security_groups.security_groups
      end

      # Public: Returns a Hash of vpc id to Hash of security group id to group name
      def vpc_security_group_id_names
        @vpc_security_group_id_names ||= Hash[vpc_security_groups.map do |vpc_id, group_hash|
          [vpc_id, Hash[group_hash.map {|_, sg| [sg.group_id, sg.group_name]}]]
        end]
      end

    end
  end
end
