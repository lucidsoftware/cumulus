require "conf/Configuration"
require "ec2/EC2"

require "aws-sdk"

module Cumulus
  module SecurityGroups
    class << self
      @@client = Aws::EC2::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)

      require "aws_extensions/ec2/SecurityGroup"
      Aws::EC2::Types::SecurityGroup.send(:include, AwsExtensions::EC2::SecurityGroup)

      def id_security_groups
        @id_security_groups ||= Hash[security_groups.map { |a| [a.group_id, a] }]
      end

      # Public: Returns a Hash of security group name to security group in the specified vpc
      def name_security_groups(vpc_id)
        @name_security_groups ||= Hash[security_groups.select { |g| g.vpc_id == vpc_id }.map { |a| [a.group_name, a] }]
      end

      # Describe all security groups that are in a vpc
      def security_groups
        @security_groups ||= @@client.describe_security_groups.security_groups.reject { |sg| sg.vpc_id.nil? }
      end

      def sg_id_names
        @sg_id_names ||= Hash[security_groups.map { |sg| [sg.group_id, sg.group_name] }]
      end

    end
  end
end
