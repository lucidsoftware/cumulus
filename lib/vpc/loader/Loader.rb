require "common/BaseLoader"
require "conf/Configuration"
require "vpc/models/RouteTableConfig"
require "vpc/models/SubnetConfig"
require "vpc/models/VpcConfig"

require "aws-sdk"

# Public: Load VPC assets
module Cumulus
  module VPC
    module Loader
      include Common::BaseLoader

      @@vpcs_dir = Configuration.instance.vpc.vpcs_directory
      @@subnets_dir = Configuration.instance.vpc.subnets_directory
      @@route_tables_dir = Configuration.instance.vpc.route_tables_directory
      @@policies_dir = Configuration.instance.vpc.policies_directory
      @@network_acls_dir = Configuration.instance.vpc.network_acls_directory

      # Public: Load all the VPC configurations as VpcConfig objects
      #
      # Returns an array of VpcConfig
      def self.vpcs
        Common::BaseLoader::resources(@@vpcs_dir, &VpcConfig.method(:new))
      end

      # Public: Load the specified policy as a JSON object
      #
      # Returns the JSON object for the policy
      def self.policy(policy_name)
        Common::BaseLoader::resource(policy_name, @@policies_dir) do |policy_name, policy|
          policy
        end
      end

      # Public: Load a subnet as a SubnetConfig
      #
      # Returns the SubnetConfig
      def self.subnet(subnet_name)
        Common::BaseLoader::resource(subnet_name, @@subnets_dir, &SubnetConfig.method(:new))
      end

      # Public: Load a route table as a RouteTableConfig
      #
      # Returns the RouteTableConfig
      def self.route_table(rt_name)
        Common::BaseLoader::resource(rt_name, @@route_tables_dir, &RouteTableConfig.method(:new))
      end

      # Public: Load a network acl as a NetworkAclConfig
      #
      # Returns the NetworkAclConfig
      def self.network_acl(acl_name)
        Common::BaseLoader::resource(acl_name, @@network_acls_dir, &NetworkAclConfig.method(:new))
      end
    end
  end
end
