require "common/BaseLoader"
require "conf/Configuration"
require "security/models/SecurityGroupConfig"
require "util/Colors"
require "util/StatusCodes"

module Cumulus
  module SecurityGroups
    # Public: Load Security Group assets
    module Loader
      include Common::BaseLoader

      @@groups_dir = Configuration.instance.security.groups_directory
      @@subnets_file = Configuration.instance.security.subnets_file

      # Public: Load all the security group configurations as SecurityGroupConfig objects
      #
      # Returns an array of SecurityGroupConfig
      def Loader.groups
        # List all the directories to load groups from each vpc
        vpc_dirs = Dir.entries(@@groups_dir).reject { |f| f == "." or f == ".."}.select { |f| File.directory?(File.join(@@groups_dir, f)) }

        vpc_groups = vpc_dirs.map do |d|
          aws_vpc = EC2::named_vpcs[d]

          if aws_vpc.nil?
            puts Colors.red("No VPC named #{d} exists")
            exit StatusCodes::EXCEPTION
          end

          Common::BaseLoader.resources(File.join(@@groups_dir, d)) do |file_name, json|
            name = "#{aws_vpc.name}/#{file_name}"
            SecurityGroupConfig.new(name, aws_vpc.vpc_id, json)
          end
        end.flatten

        non_vpc_groups = if EC2::supports_ec2_classic
          Common::BaseLoader.resources(@@groups_dir) do |file_name, json|
            SecurityGroupConfig.new(file_name, nil, json)
          end
        else
          puts "Ignoring Non-VPC Security Groups because your account does not support them"
          []
        end

        vpc_groups + non_vpc_groups
      end

      # Public: Get the local definition of a subnet group.
      #
      # name - the name of the subnet group to get
      #
      # Returns an array of ip addresses that is empty if there is no subnet group with that name
      def Loader.subnet_group(name)
        if self.subnet_groups[name].nil?
          []
        else
          self.subnet_groups[name]
        end
      end

      private

      # Internal: Get the subnet group definitions
      #
      # Returns a hash that maps group name to an array of ips
      def Loader.subnet_groups
        @subnet_groups ||= self.load_subnet_groups
      end

      # Internal: Load the subnet group definitions
      #
      # Returns a hash that maps group name to an array of ips
      def Loader.load_subnet_groups
        Common::BaseLoader.resource(@@subnets_file, "", &Proc.new { |name, json| json })
      end
    end
  end
end
