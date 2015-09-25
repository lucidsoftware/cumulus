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
      DHCP = Common::DiffChange.next_change_id
      ROUTE_TABLES = Common::DiffChange.next_change_id
      ENDPOINTS = Common::DiffChange.next_change_id
      ADDRESSES = Common::DiffChange.next_change_id
      NETWORK_ACLS = Common::DiffChange.next_change_id
      SUBNETS = Common::DiffChange.next_change_id
      TAGS = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class VpcDiff < Common::Diff
      include VpcChange
      include Common::TagsDiff

      def self.subnets(aws, local)
        aws_name_subnets = Hash[aws.map { |subnet| [subnet.name || subnet.subnet_id, subnet] }]
        local_name_subnets = Hash[local.map { |subnet| [subnet.name, subnet] }]

        added = local_name_subnets.reject { |k, v| aws_name_subnets.has_key? k }
        removed = aws_name_subnets.reject { |k, v| local_name_subnets.has_key? k }
        modified = local_name_subnets.select { |k, v| aws_name_subnets.has_key? k }

        added_diffs = Hash[added.map { |subnet_name, subnet| [subnet_name, SubnetDiff.added(subnet)] }]
        removed_diffs = Hash[removed.map { |subnet_name, subnet| [subnet_name, SubnetDiff.unmanaged(subnet)] }]
        modified_diffs = Hash[modified.map do |subnet_name, subnet|
          aws_subnet = aws_name_subnets[subnet_name]
          subnet_diffs = subnet.diff(aws_subnet)
          if !subnet_diffs.empty?
            [subnet_name, SubnetDiff.modified(aws_subnet, subnet, subnet_diffs)]
          end
        end.reject { |v| v.nil? }]

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = VpcDiff.new(SUBNETS, aws, local)
          diff.changes = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      def self.dhcp(aws, local)
        dhcp_diffs = local.diff(aws)
        if !dhcp_diffs.empty?
          diff = VpcDiff.new(DHCP, aws, local)
          diff.changes = dhcp_diffs
          diff
        end
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
          aws_rt = aws_name_route_tables[rt_name]
          rt_diffs = rt.diff(aws_rt)
          if !rt_diffs.empty?
            [rt_name, RouteTableDiff.modified(aws_rt, rt, rt_diffs)]
          end
        end.reject { |v| v.nil? }]

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = VpcDiff.new(ROUTE_TABLES, aws, local)
          diff.changes = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
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
          aws_endpoint = aws_service_endpoints[service_name]
          endpoint_diffs = endpoint.diff(aws_endpoint)
          if !endpoint_diffs.empty?
            [service_name, EndpointDiff.modified(aws_endpoint, endpoint, endpoint_diffs)]
          end
        end.reject { |v| v.nil? }]

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = VpcDiff.new(ENDPOINTS, aws, local)
          diff.changes = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      AddressChange = Struct.new(:aws_name, :aws, :local_name, :local)
      def self.address_associations(aws, local)
        # Map the aws and local public ips to network interface
        aws_addresses = Hash[aws.map { |addr| [addr.public_ip, EC2::id_network_interfaces[addr.network_interface_id]] }]

        local_addresses = Hash[local.map do |ip, key|
          interface = EC2::named_network_interfaces[key]

          if interface.nil?
            puts Colors.red("Config error: no network interface exists for #{key}")
            exit 1
          end

          [ip, interface]
        end].reject { |k, v| v.nil? }

        added = local_addresses.reject { |k, v| aws_addresses.has_key? k }
        added_names = Hash[added.map { |ip, interface| [ip, AddressChange.new(nil, nil, interface.name || interface.network_interface_id,  interface)] }]

        removed = aws_addresses.reject { |k, v| local_addresses.has_key? k }
        removed_names = Hash[removed.map { |ip, interface| [ip, AddressChange.new(interface.name || interface.network_interface_id, interface, nil, nil)] }]

        modified = local_addresses.select { |k, v| aws_addresses.has_key? k and aws_addresses[k].network_interface_id != v.network_interface_id }
        modified_changes = Hash[modified.map do |ip, local_interface|
            aws_interface = aws_addresses[ip]
            aws_name = aws_interface.name || aws_interface.network_interface_id
            local_name = local_interface.name || local_interface.network_interface_id
          [ip, AddressChange.new(aws_name, aws_interface, local_name, local_interface)]
        end]

        if !added_names.empty? or !removed_names.empty? or !modified_changes.empty?
          diff = VpcDiff.new(ADDRESSES, aws, local_addresses)
          diff.changes = Common::ListChange.new(added_names, removed_names, modified_changes)
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
          aws_acl = aws_network_acl_names[name]
          acl_diffs = acl.diff(aws_acl)
          if !acl_diffs.empty?
            [name, NetworkAclDiff.modified(aws_acl, acl, acl_diffs)]
          end
        end.reject { |v| v.nil? }]

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = VpcDiff.new(NETWORK_ACLS, aws, local)
          diff.changes = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
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
        @aws.name || @aws.vpc_id
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
            @changes.removed.map { |s, _| Colors.unmanaged("\t#{s} is not managed by Cumulus") },
            @changes.added.map { |s, _| Colors.added("\t#{s} will be created") },
            @changes.modified.map do |subnet_name, diff|
              [
                "\t#{subnet_name}:",
                diff.changes.map do |diff|
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
        when ROUTE_TABLES
          [
            "Route Tables:",
            @changes.removed.map { |r, _| Colors.unmanaged("\t#{r} will be deleted") },
            @changes.added.map { |r, _| Colors.added("\t#{r} will be created") },
            @changes.modified.map do |rt_name, diff|
              [
                "\t#{rt_name}:",
                diff.changes.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        when ENDPOINTS
          [
            "Endpoints:",
            @changes.removed.map { |e, _| Colors.unmanaged("\t#{e} will be deleted") },
            @changes.added.map { |e, _| Colors.added("\t#{e} will be created") },
            @changes.modified.map do |endpoint_name, diff|
              [
                "\t#{endpoint_name}:",
                diff.changes.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        when ADDRESSES
          [
            "Address Associations:",
            @changes.removed.map { |ip, addr_change| Colors.unmanaged("\t#{ip} will be disassociated from #{addr_change.aws_name}") },
            @changes.added.map { |ip, addr_change| Colors.added("\t#{ip} will be associated to #{addr_change.local_name}") },
            @changes.modified.map do |ip, addr_change|
              "\t#{ip} will be changed from #{addr_change.aws_name} to #{addr_change.local_name}"
            end
          ].flatten.join("\n")
        when NETWORK_ACLS
          [
            "Network ACLs:",
            @changes.removed.map { |acl_name, _| Colors.unmanaged("\t#{acl_name} will be deleted") },
            @changes.added.map { |acl_name, _| Colors.added("\t#{acl_name} will be created") },
            @changes.modified.map do |acl_name, diff|
              [
                "\t#{acl_name}:",
                diff.changes.map do |diff|
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
