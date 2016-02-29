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
      @@rules_dir = Configuration.instance.security.rules_directory
      @@subnet_files = Configuration.instance.security.subnet_files

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

        non_vpc_groups = Common::BaseLoader.resources(@@groups_dir) do |file_name, json|
          SecurityGroupConfig.new(file_name, nil, json)
        end

        if !EC2::supports_ec2_classic and !non_vpc_groups.empty?
          puts "Ignoring Non-VPC Security Groups because your account does not support them"
          non_vpc_groups = []
        end

        vpc_groups + non_vpc_groups
      end

      # Public: Load a single static rule
      #
      # Returns the static rule as json
      def Loader.rule(rule_name)
        Common::BaseLoader.resource(rule_name, @@rules_dir) { |_, json| json }
      end

      # Public: Get the local definition of a subnet group.
      #
      # name - the name of the subnet group to get
      #
      # Returns an array of ip addresses that is empty if there is no subnet group with that name
      def Loader.subnet_group(name)
        if self.subnet_groups[name].nil?
          raise "Could not find subnet #{name}"
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
        @@subnet_files.reduce({}) do |sofar, f|
          subnet_group = Common::BaseLoader.resource(f, "") { |_, json| json }
          if subnet_group
            subnet_group.merge(sofar)
          else
            sofar
          end
        end
      end
    end
  end
end
