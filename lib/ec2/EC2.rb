require "conf/Configuration"
require "ec2/models/EbsGroupConfig"

require "aws-sdk"

module Cumulus
  module EC2
    class << self
      @@client = Aws::EC2::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)

      require "aws_extensions/ec2/Subnet"
      Aws::EC2::Types::Subnet.send(:include, AwsExtensions::EC2::Subnet)

      require "aws_extensions/ec2/Vpc"
      Aws::EC2::Types::Vpc.send(:include, AwsExtensions::EC2::Vpc)

      require "aws_extensions/ec2/RouteTable"
      Aws::EC2::Types::RouteTable.send(:include, AwsExtensions::EC2::RouteTable)

      require "aws_extensions/ec2/NetworkAcl"
      Aws::EC2::Types::NetworkAcl.send(:include, AwsExtensions::EC2::NetworkAcl)

      require "aws_extensions/ec2/NetworkInterface"
      Aws::EC2::Types::NetworkInterface.send(:include, AwsExtensions::EC2::NetworkInterface)

      require "aws_extensions/ec2/VpcEndpoint"
      Aws::EC2::Types::VpcEndpoint.send(:include, AwsExtensions::EC2::VpcEndpoint)

      require "aws_extensions/ec2/Volume"
      Aws::EC2::Types::Volume.send(:include, AwsExtensions::EC2::Volume)

      require "aws_extensions/ec2/Instance"
      Aws::EC2::Types::Instance.send(:include, AwsExtensions::EC2::Instance)

      # Public
      #
      # Returns a Hash of subnet id to Aws::EC2::Types::Subnet
      def id_subnets
        @id_subnets ||= Hash[subnets.map { |subnet| [subnet.subnet_id, subnet] }]
      end

      # Public
      #
      # Returns a Hash of subnet name or id to Aws::EC2::Types::Subnet
      def named_subnets
        @named_subnets ||= Hash[subnets.map { |subnet| [subnet.name || subnet.subnet_id, subnet] }]
          .reject { |k, v| !k or !v }
      end

      # Public
      #
      # Returns a Hash of VPC id to array of Aws::EC2::Types::Subnet for the VPC
      def vpc_subnets
        @vpc_subnets ||= Hash[id_vpcs.map do |vpc_id, _|
          [vpc_id, subnets.select { |subnet| subnet.vpc_id == vpc_id }]
        end]
      end

      # Public: Lazily load the subnets
      def subnets
        @subnets ||= init_subnets
      end

      # Public
      #
      # Returns a Hash of VPC name or id to Aws::EC2::Types::Vpc
      def named_vpcs
        @named_vpcs ||= Hash[vpcs.map { |vpc| [vpc.name || vpc.vpc_id, vpc] }]
          .reject { |k, v| !k or !v }
      end

      # Public
      #
      # Returns a Hash of VPC id to Aws::EC2::Types::Vpc
      def id_vpcs
        @vpc_ids ||= Hash[vpcs.map { |vpc| [vpc.vpc_id, vpc] }]
      end

      # Public refreshes the list of vpcs
      def refresh_vpcs!
        @vpcs = init_vpcs
      end

      # Public: Lazily load the vpcs
      def vpcs
        @vpcs ||= init_vpcs
      end

      # Public
      #
      # Returns a Hash of route tables name or id to Aws::EC2::Types::RouteTable
      def named_route_tables
        @named_route_tables ||= Hash[route_tables.map { |rt| [rt.name || rt.route_table_id, rt] }]
          .reject { |k, v| !k or !v }
      end

      # Public
      #
      # Returns a Hash of subnet id to Aws::EC2::Types::RouteTable
      def subnet_route_tables
        @subnet_route_tables ||= Hash[route_tables.flat_map do |rt|
          rt.subnet_ids.map { |subnet_id| [subnet_id, rt] }
        end]
      end

      # Public
      #
      # Returns a Hash of vpc id to array of Aws::EC2::Types::RouteTable
      def vpc_route_tables
        @vpc_route_tables ||= Hash[id_vpcs.map do |vpc_id, _|
          [vpc_id, route_tables.select { |rt| rt.vpc_id == vpc_id }]
        end]
      end

      # Public
      #
      # Returns a Hash of route table id Aws::EC2::Types::RouteTable
      def id_route_tables
        @id_route_tables ||= Hash[@route_tables.map { |rt| [rt.route_table_id, rt] }]
      end

      # Public: Lazily load route tables
      def route_tables
        @route_tables ||= init_route_tables
      end

      # Public refreshes the list of route tables
      def refresh_route_tables!
        @route_tables = init_route_tables
      end

      # Public
      #
      # Returns a Hash of subnet id to Aws::EC2::Types::NetworkAcl associated with the subnet
      def subnet_network_acls
        @subnet_network_acls ||=
        Hash[network_acls.flat_map do |acl|
          acl.subnet_ids.map { |subnet_id| [subnet_id, acl] }
        end]
      end

      # Public
      #
      # Returns a Hash of vpc id to array of Aws::EC2::Types::NetworkAcl
      def vpc_network_acls
        @vpc_network_acls = Hash[id_vpcs.map do |vpc_id, _|
          [vpc_id, network_acls.select { |acl| acl.vpc_id == vpc_id }]
        end]
      end

      # Public
      #
      # Returns a Hash of network acl name or id to Aws::EC2::Types::NetworkAcl
      def named_network_acls
        @named_network_acls = Hash[network_acls.map do |acl|
          [acl.name || acl.network_acl_id, acl]
        end]
      end

      # Public: Lazily load the network acls
      def network_acls
        @network_acls ||= init_network_acls
      end

      # Public: Refresh the list of Network ACLs
      def refresh_network_acls!
        @network_acls = init_network_acls
      end

      # Public
      #
      # Returns a Hash of dhcp options id to Aws::EC2::Types::DhcpOptions
      def id_dhcp_options
        @id_dhcp_options ||= Hash[dhcp_options.map { |dhcp| [dhcp.dhcp_options_id, dhcp] }]
      end

      # Public: Lazily load the dhcp options
      def dhcp_options
        @dhcp_options ||= init_dhcp_options
      end

      # Public: Lazily load the vpc endpoints
      #
      # Returns a Hash of vpc id to array of Aws::EC2::Types::VpcEndpoint
      def vpc_endpoints
        @vpc_endpoints ||= Hash[id_vpcs.map do |vpc_id, _|
          [vpc_id, endpoints.select { |e| e.vpc_id == vpc_id } ]
        end]
      end

      # Public: Lazily load the endpoints
      def endpoints
        @endpoints ||= init_endpoints
      end

      # Public
      #
      # Returns a Hash of public ip to Aws::EC2::Types::Address
      def public_addresses
        @public_addresses ||= Hash[addresses.map { |addr| [addr.public_ip, addr] }]
      end

      # Public
      #
      # Returns a Hash of vpc id to array of Aws::EC2::Types::Address that has a network interface in the vpc
      def vpc_addresses
        @vpc_addresses ||= Hash[id_vpcs.map do |vpc_id, _|
          interface_ids = vpc_network_interfaces[vpc_id].map { |interface| interface.network_interface_id }
          [vpc_id, addresses.select { |addr| interface_ids.include? addr.network_interface_id }]
        end]
      end

      # Public: Lazily load the addresses
      def addresses
        @addresses ||= init_addresses
      end

      # Public
      #
      # Returns a Hash of interface name to Aws::EC2::Types::NetworkInterface
      def named_network_interfaces
        @named_network_interfaces ||= Hash[network_interfaces.map { |net| [net.name || net.network_interface_id, net] }]
          .reject { |k, v| !k or !v }
      end

      # Public
      #
      # Returns a Hash of interface id to Aws::EC2::Types::NetworkInterface
      def id_network_interfaces
        @id_network_interfaces ||= Hash[network_interfaces.map { |net| [net.network_interface_id, net] }]
      end

      # Public
      #
      # Returns a Hash of vpc id to array of Aws::EC2::Types::NetworkInterface
      def vpc_network_interfaces
        @vpc_network_interfaces ||= Hash[id_vpcs.map do |vpc_id, _|
          [vpc_id, network_interfaces.select { |net| net.vpc_id == vpc_id}]
        end]
      end

      # Public: Lazily load network interfaces
      def network_interfaces
        @network_interfaces ||= init_network_interfaces
      end

      # Public
      #
      # Returns a Hash of ebs volume group name to EbsGroupConfig
      def group_ebs_volumes
        @group_ebs_volumes ||= Hash[ebs_groups.map do |group_name|
          vols = ebs_volumes.select { |vol| vol.group == group_name}
          [group_name, EbsGroupConfig.new(group_name).populate!(vols)]
        end]
      end

      # Public
      #
      # Returns an array of the group names used by all ebs volumes
      def ebs_groups
        @ebs_groups ||= ebs_volumes.map(&:group).reject(&:nil?).uniq
      end

      # Public: Lazily loads EBS volumes, rejecting all root-mounted volumes
      def ebs_volumes
        @ebs_volumes ||= init_ebs_volumes.reject do |vol|
          vol.attachments.any? do |att|
            attached_instance = id_instances[att.instance_id]
            attached_instance.root_device_name == att.device
          end
        end
      end

      # Public
      #
      # Returns a Hash of instance id to Aws::EC2::Types::Instance
      def id_instances
        @id_instances ||= Hash[instances.map { |i| [i.instance_id, i] }]
      end

      # Public: Lazily loads instances
      def instances
        @instances ||= init_instances
      end

      # Public
      #
      # Returns a Hash of key pair name to Aws::EC2::Types::KeyPairInfo
      def name_key_pairs
        @name_key_pairs ||= Hash[key_pairs.map { |kp| [kp.key_name, kp] }]
      end

      # Public: Lazily load key pairs
      def key_pairs
        @key_pairs ||= init_key_pairs
      end

      private

      # Internal: Load all subnets
      #
      # Returns an array of Aws::EC2::Types::Subnet
      def init_subnets
        @@client.describe_subnets.subnets
      end

      # Internal: Load VPCs
      #
      # Returns the VPCs as Aws::EC2::Types::Vpc
      def init_vpcs
        @@client.describe_vpcs.vpcs
      end

      # Internal: Load route tables
      #
      # Returns the route tables as Aws::EC2::Types::RouteTable
      def init_route_tables
        @@client.describe_route_tables.route_tables
      end

      # Internal: Load network acls
      #
      # Returns the network acls as Aws::EC2::Types::NetworkAcl
      def init_network_acls
        @@client.describe_network_acls.network_acls
      end

      # Internal: Load DHCP Options
      #
      # Returns the dhcp options as Aws::EC2::Types::DhcpOptions
      def init_dhcp_options
        @@client.describe_dhcp_options.dhcp_options
      end

      # Internal: Load VPC Endpoints
      #
      # Returns the vpc endpoints as Aws::EC2::Types::VpcEndpoint
      def init_endpoints
        endpoints = []
        next_token = nil
        all_records_retrieved = false

        until all_records_retrieved
          response = @@client.describe_vpc_endpoints({
            next_token: next_token
          })
          next_token = response.next_token
          all_records_retrieved = next_token.nil? || next_token.empty?
          endpoints << response.vpc_endpoints
        end

        endpoints.flatten
      end

      # Internal: Load allocated addresses
      #
      # Returns the address as Aws::EC2::Types::Address
      def init_addresses
        @@client.describe_addresses.addresses
      end

      # Internal: Load network interfaces
      #
      # Returns the network interface as Aws::EC2::Types::NetworkInterface
      def init_network_interfaces
        @@client.describe_network_interfaces.network_interfaces
      end

      # Internal: Load EBS Volumes
      #
      # Returns the volumes as Aws::EC2::Types::Volume
      def init_ebs_volumes
        @@client.describe_volumes.volumes
      end

      # Internal: Load instances
      #
      # Returns the instances as Aws::EC2::Types::Instance
      def init_instances
        instances = []
        next_token = nil
        all_records_retrieved = false

        until all_records_retrieved
          response = @@client.describe_instances({
            next_token: next_token
          })
          next_token = response.next_token
          all_records_retrieved = next_token.nil? || next_token.empty?
          instances << response.reservations.map { |r| r.instances }
        end

        instances.flatten
      end

      # Internal: Load SSH key pairs
      #
      # Returns the keys as Aws::EC2::Types::KeyPairInfo
      def init_key_pairs
        @@client.describe_key_pairs.key_pairs
      end

    end
  end
end
