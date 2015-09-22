require "common/models/Diff"
require "common/models/ListChange"
require "common/models/TagsDiff"
require "vpc/models/SubnetDiff"
require "vpc/models/RouteTableDiff"
require "vpc/models/EndpointDiff"
require "vpc/models/NetworkAclDiff"
require "ec2/EC2"
require "util/Colors"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to a VPC
    module VpcChange
      include Common::DiffChange

      CIDR = Common::DiffChange.next_change_id
      TENANCY = Common::DiffChange.next_change_id
      SUBNETS = Common::DiffChange.next_change_id
      DHCP = Common::DiffChange.next_change_id
      ROUTE = Common::DiffChange.next_change_id
      ENDPOINTS = Common::DiffChange.next_change_id
      ADDRESSES = Common::DiffChange.next_change_id
      NETWORK = Common::DiffChange.next_change_id
      TAGS = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class VpcDiff < Common::Diff
      include VpcChange
      include Common::TagsDiff

      attr_accessor :subnets
      attr_accessor :dhcp
      attr_accessor :route_tables
      attr_accessor :endpoints
      attr_accessor :addresses
      attr_accessor :network_acls

      def self.subnets(aws, local)
        aws_name_subnets = Hash[aws.map { |subnet| [subnet.name || subnet.subnet_id, subnet] }]
        local_name_subnets = Hash[local.map { |subnet| [subnet.name, subnet] }]

        added = local_name_subnets.reject { |k, v| aws_name_subnets.has_key? k }
        removed = aws_name_subnets.reject { |k, v| local_name_subnets.has_key? k }
        modified = local_name_subnets.select { |k, v| aws_name_subnets.has_key? k }

        added_diffs = Hash[added.map { |subnet_name, subnet| [subnet_name, SubnetDiff.added(subnet)] }]
        removed_diffs = Hash[removed.map { |subnet_name, subnet| [subnet_name, SubnetDiff.unmanaged(subnet)] }]
        modified_diffs = Hash[modified.map do |subnet_name, subnet|
          [subnet_name, subnet.diff(aws_name_subnets[subnet_name])]
        end].reject { |k, v| v.empty? }

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = VpcDiff.new(SUBNETS, aws, local)
          diff.subnets = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      def self.dhcp(dhcp_diffs, aws, local)
        diff = VpcDiff.new(DHCP, aws, local)
        diff.dhcp = dhcp_diffs
        diff
      end

      def self.route_tables(aws, local)
        aws_name_route_tables = Hash[aws.map { |rt| [rt.name || rt.route_table_id, rt] }]
        local_name_route_tables = Hash[local.map { |rt| [rt.name, rt] }]

        added = local_name_route_tables.reject { |k, v| aws_name_route_tables.has_key? k }
        removed = aws_name_route_tables.reject { |k, v| local_name_route_tables.has_key? k }
        modified = local_name_route_tables.select { |k, v| aws_name_route_tables.has_key? k }

        added_diffs = Hash[added.map { |rt_name, rt| [rt_name, RouteTableDiff.added(rt)]}]
        removed_diffs = Hash[removed.map { |rt_name, rt| [rt_name, RouteTableDiff.unmanaged(rt)]}]
        modified_diffs = Hash[modified.map do |rt_name, rt|
          [rt_name, rt.diff(aws_name_route_tables[rt_name])]
        end].reject { |k, v| v.empty? }

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = VpcDiff.new(ROUTE, aws, local)
          diff.route_tables = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      def self.endpoints(aws, local)
        aws_service_endpoints = Hash[aws.map { |e| [e.service_name, e] }]
        local_service_endpoints = Hash[local.map { |e| [e.service_name, e] }]

        added = local_service_endpoints.reject { |k, v| aws_service_endpoints.has_key? k }
        removed = aws_service_endpoints.reject { |k, v| local_service_endpoints.has_key? k }
        modified = local_service_endpoints.select { |k, v| aws_service_endpoints.has_key? k }

        added_diffs = Hash[added.map { |service_name, endpoint| [service_name, EndpointDiff.added(endpoint)]}]
        removed_diffs = Hash[removed.map { |service_name, endpoint| [service_name, EndpointDiff.unmanaged(endpoint)]}]
        modified_diffs = Hash[modified.map do |service_name, endpoint|
          [service_name, endpoint.diff(aws_service_endpoints[service_name])]
        end].reject { |k, v| v.empty? }

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = VpcDiff.new(ENDPOINTS, aws, local)
          diff.endpoints = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      AddressChange = Struct.new(:aws, :local)
      def self.address_associations(aws, local)
        # Map the aws and local public ips to network interface
        aws_addresses = Hash[aws.map { |addr| [addr.public_ip, EC2::id_network_interfaces[addr.network_interface_id]] }]

        local_addresses = Hash[local.map do |ip, ref|
          interface = EC2::named_network_interfaces[ref] || EC2::id_network_interfaces[ref]

          if interface.nil?
            puts Colors.red("Config error: no network interface exists for #{ref}")
            exit 1
          end

          [ip, interface]
        end].reject { |k, v| v.nil? }

        added = local_addresses.reject { |k, v| aws_addresses.has_key? k }
        added_names = Hash[added.map { |ip, interface| [ip, interface.name || interface.network_interface_id] }]

        removed = aws_addresses.reject { |k, v| local_addresses.has_key? k }
        removed_names = Hash[removed.map { |ip, interface| [ip, interface.name || interface.network_interface_id] }]

        modified = local_addresses.select { |k, v| aws_addresses.has_key? k and aws_addresses[k].network_interface_id != v.network_interface_id }
        modified_changes = Hash[modified.map { |key, local_v| [key, AddressChange.new(aws_addresses[key], local_v)] }]

        if !added_names.empty? or !removed_names.empty? or !modified_changes.empty?
          diff = VpcDiff.new(ADDRESSES, aws, local_addresses)
          diff.addresses = Common::ListChange.new(added_names, removed_names, modified_changes)
          diff
        end
      end

      def self.network_acls(aws, local)
        aws_network_acl_names = Hash[aws.map { |acl| [acl.name || acl.network_acl_id, acl] }]
        local_network_acl_names = Hash[local.map { |acl| [acl.name, acl] }]

        added = local_network_acl_names.reject { |k, v| aws_network_acl_names.has_key? k }
        removed = aws_network_acl_names.reject { |k, v| local_network_acl_names.has_key? k }
        modified = local_network_acl_names.select { |k, v| aws_network_acl_names.has_key? k }

        added_diffs = Hash[added.map { |name, acl| [name, NetworkAclDiff.added(acl)] }]
        removed_diffs = Hash[removed.map { |name, acl| [name, NetworkAclDiff.unmanaged(acl)] }]
        modified_diffs = Hash[modified.map do |name, acl|
          [name, acl.diff(aws_network_acl_names[name])]
        end].reject { |k, v| v.empty? }

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = VpcDiff.new(NETWORK, aws, local)
          diff.network_acls = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      def local_tags
        @local
      end

      def aws_tags
        @aws
      end

      def asset_type
        "Virtual Private Cloud"
      end

      def aws_name
        @aws.name
      end

      def diff_string
        case @type
        when CIDR
          [
            "CIDR Block:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when TENANCY
          [
            "Tenancy:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when SUBNETS
          [
            "Subnets:",
            @subnets.removed.map { |s, _| Colors.unmanaged("\t#{s} is not managed by Cumulus") },
            @subnets.added.map { |s, _| Colors.added("\t#{s} will be created") },
            @subnets.modified.map do |subnet_name, diffs|
              [
                "\t#{subnet_name}:",
                diffs.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        when DHCP
          [
            "DHCP Options:",
            @dhcp.map do |diff|
              diff.to_s.lines.map { |l| "\t#{l}".chomp("\n") }
            end
          ].flatten.join("\n")
        when ROUTE
          [
            "Route Tables:",
            @route_tables.removed.map { |r, _| Colors.unmanaged("\t#{r} will be deleted") },
            @route_tables.added.map { |r, _| Colors.added("\t#{r} will be created") },
            @route_tables.modified.map do |rt_name, diffs|
              [
                "\t#{rt_name}:",
                diffs.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        when ENDPOINTS
          [
            "Endpoints:",
            @endpoints.removed.map { |e, _| Colors.unmanaged("\t#{e} will be deleted") },
            @endpoints.added.map { |e, _| Colors.added("\t#{e} will be created") },
            @endpoints.modified.map do |endpoint_name, diffs|
              [
                "\t#{endpoint_name}:",
                diffs.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        when ADDRESSES
          [
            "Address Associations:",
            @addresses.removed.map { |ip, n| Colors.unmanaged("\t#{ip} will be disassociated from #{n}") },
            @addresses.added.map { |ip, n| Colors.added("\t#{ip} will be associated to #{n}") },
            @addresses.modified.map do |ip, change|
              aws_name = change.aws.name || change.aws.network_interface_id
              local_name = change.local.name || change.local.network_interface_id
              "\t#{ip} will be changed from #{aws_name} to #{local_name}"
            end
          ].flatten.join("\n")
        when NETWORK
          [
            "Network ACLs:",
            @network_acls.removed.map { |acl_name, _| Colors.unmanaged("\t#{acl_name} will be deleted") },
            @network_acls.added.map { |acl_name, _| Colors.added("\t#{acl_name} will be created") },
            @network_acls.modified.map do |acl_name, diffs|
              [
                "\t#{acl_name}:",
                diffs.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        when TAGS
          tags_diff_string
        end
      end
    end
  end
end
