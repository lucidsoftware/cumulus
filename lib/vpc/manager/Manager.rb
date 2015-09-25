require "common/manager/Manager"
require "conf/Configuration"
require "util/Colors"
require "vpc/loader/Loader"
require "vpc/models/VpcDiff"
require "vpc/models/RouteTableDiff"
require "vpc/models/EndpointDiff"
require "vpc/models/NetworkAclDiff"
require "vpc/models/SubnetDiff"
require "ec2/EC2"
require "ec2/IPProtocolMapping"

require "aws-sdk"
require "json"

module Cumulus
  module VPC
    class Manager < Common::Manager

      include VpcChange

      def initialize
        super()
        @create_asset = false
        @client = Aws::EC2::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)
      end

      def resource_name
        "Virtual Private Cloud"
      end

      def local_resources
        @local_resources ||= Hash[Loader.vpcs.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= EC2::named_vpcs
      end

      def unmanaged_diff(aws)
        VpcDiff.unmanaged(aws)
      end

      def added_diff(local)
        VpcDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      def update(local, diffs)
        aws_vpc = EC2::named_vpcs[local.name]

        diffs.each do |diff|
          case diff.type
          when CIDR
            puts Colors.blue("CIDR Block cannot be updated. You must create a new VPC.")
          when TENANCY
            puts Colors.blue("Tenancy cannot be updated. You must create a new VPC.")
          when DHCP
            puts Colors.blue("Updating DHCP Options...")
            update_dhcp_options(aws_vpc, local.dhcp)
          when ROUTE_TABLES
            puts Colors.blue("Updating Route Tables...")
            update_route_tables(aws_vpc, diff.changes)
          when ENDPOINTS
            puts Colors.blue("Updating Endpoints...")
            update_endpoints(aws_vpc, diff.changes)
          when ADDRESSES
            puts Colors.blue("Updating Address Associations...")
            update_address_associations(aws_vpc, diff.changes)
          when NETWORK_ACLS
            puts Colors.blue("Updating Network ACLs")
            update_network_acls(aws_vpc, diff.changes)
          when SUBNETS
            puts Colors.blue("Updating Subnets...")
            update_subnets(aws_vpc, diff.changes)
          when TAGS
            puts Colors.blue("Updating Tags...")

            if !diff.tags_to_remove.empty?
              delete_tags(aws_vpc.vpc_id, diff.tags_to_remove)
            end

            if !diff.tags_to_add.empty?
              create_tags(aws_vpc.vpc_id, diff.tags_to_add)
            end
          end
        end

      end

      private

      def create_tags(resource_id, tags)
        @client.create_tags({
          resources: [resource_id],
          tags: tags.map do |key, value|
            {
              key: key,
              value: value
            }
          end
        })
      end

      def delete_tags(resource_id, tags)
        @client.delete_tags({
          resources: [resource_id],
          tags: tags.map do |key, value|
            {
              key: key,
              value: value
            }
          end
        })
      end

      def update_dhcp_options(aws_vpc, dhcp_config)
        old_options_id = aws_vpc.dhcp_options_id

        dhcp_options = dhcp_config.to_aws

        options_id = if dhcp_options.empty?
          "default"
        else
          @client.create_dhcp_options({
            dhcp_configurations: dhcp_options
          }).dhcp_options.dhcp_options_id
        end

        @client.associate_dhcp_options({
          vpc_id: aws_vpc.vpc_id,
          dhcp_options_id: options_id
        })

        EC2::refresh_vpcs!

        # Delete the old options if no other vpc depends on it
        if !EC2::vpcs.any? { |vpc| vpc.dhcp_options_id == old_options_id }
          @client.delete_dhcp_options({
            dhcp_options_id: old_options_id
          })
        end
      end

      def update_route_tables(aws_vpc, rt_changes)
        # Added route tables
        rt_changes.added.each do |rt_name, added_diff|
          added_rt = added_diff.local

          puts "Creating route table #{rt_name}"
          create_route_table(aws_vpc.vpc_id, added_rt)
        end

        # Removed route tables
        rt_changes.removed.each do |rt_name, removed_diff|
          removed_rt = removed_diff.aws

          # Make sure it is not the main route table
          if removed_rt.associations.any? { |assoc| assoc.main }
            puts Colors.red("Cannot delete main route table #{rt_name}")
          else
            puts "Deleting route table #{rt_name}"
            delete_route_table(removed_rt)
          end
        end

        # Modified route tables
        rt_changes.modified.each do |rt_name, modified_diff|
          puts "Updating #{rt_name}"
          aws_rt = EC2::named_route_tables[rt_name]
          aws_rt_id = aws_rt.route_table_id

          modified_diff.changes.each do |diff|
            case diff.type
            when RouteTableChange::ROUTES
              # Added routes
              diff.changes.added.each do |cidr, route_diff|
                create_route(aws_rt_id, route_diff.local)
              end

              # Removed routes
              diff.changes.removed.each do |cidr, route_diff|
                delete_route(aws_rt_id, route_diff.aws.destination_cidr_block)
              end

              # Modified routes
              diff.changes.modified.each do |cidr, route_diff|
                replace_route(aws_rt_id, route_diff.local)
              end
            when RouteTableChange::VGWS
              # Added vgws
              diff.changes.added.each do |vgw|
                enable_vgw(aws_rt_id, vgw)
              end

              # Removed vgws
              diff.changes.removed.each do |vgw|
                disable_vgw(aws_rt_id, vgw)
              end
            when RouteTableChange::TAGS
              if !diff.tags_to_remove.empty?
                delete_tags(aws_rt_id, diff.tags_to_remove)
              end

              if !diff.tags_to_add.empty?
                create_tags(aws_rt_id, diff.tags_to_add)
              end
            end
          end
        end
      end

      def create_route_table(vpc_id, rt)
        rt_id = @client.create_route_table({
          vpc_id: vpc_id
        }).route_table.route_table_id

        if !rt.tags.empty?
          create_tags(rt_id, rt.tags)
        end

        rt.propagate_vgws.each do |vgw|
          enable_vgw(rt_id, vgw)
        end

        rt.routes.each do |route|
          create_route(rt_id, route)
        end
      end

      def delete_route_table(aws_rt)
        # First have to disassociate all of the subnets from the route table
        aws_rt.associations.each do |assoc|
          @client.disassociate_route_table({
            association_id: assoc.route_table_association_id
          })
        end

        # Delete the route table
        @client.delete_route_table({
          route_table_id: aws_rt.route_table_id
        })
      end

      def create_route(rt_id, route)
        puts "Creating route #{route.dest_cidr}"
        @client.create_route({
          route_table_id: rt_id,
          destination_cidr_block: route.dest_cidr,
          gateway_id: if route.gateway_id then route.gateway_id end,
          instance_id: if route.instance_id then route.instance_id end,
          network_interface_id: if route.network_interface_id then route.network_interface_id end,
          vpc_peering_connection_id: if route.vpc_peering_connection_id then route.vpc_peering_connection_id end
        })
      end

      def delete_route(rt_id, dest_cidr)
        puts "Deleting route #{dest_cidr}"
        @client.delete_route({
          route_table_id: rt_id,
          destination_cidr_block: dest_cidr
        })
      end

      def replace_route(rt_id, route)
        puts "Replacing route #{route.dest_cidr}"
        @client.replace_route({
          route_table_id: rt_id,
          destination_cidr_block: route.dest_cidr,
          gateway_id: if route.gateway_id then route.gateway_id end,
          instance_id: if route.instance_id then route.instance_id end,
          network_interface_id: if route.network_interface_id then route.network_interface_id end,
          vpc_peering_connection_id: if route.vpc_peering_connection_id then route.vpc_peering_connection_id end
        })
      end

      def enable_vgw(rt_id, vgw)
        @client.enable_vgw_route_propagation({
          route_table_id: rt_id,
          gateway_id: vgw
        })
      end

      def disable_vgw(rt_id, vgw)
        @client.disable_vgw_route_propagation({
          route_table_id: rt_id,
          gateway_id: vgw
        })
      end

      def update_endpoints(aws_vpc, endpoint_changes)

        def rt_ids(rt_names)
          rt_names.map do |rt_name|
            aws_rt = EC2::named_route_tables[rt_name]
            if aws_rt.nil?
              puts Colors.red("Error updating endpoints. No route table found for #{rt_name}.")
              exit 1
            else
              aws_rt.route_table_id
            end
          end
        end

        # Added endpoints
        endpoint_changes.added.each do |endpoint_name, added_diff|
          puts "Adding endpoint #{endpoint_name}"
          endpoint = added_diff.local

          @client.create_vpc_endpoint({
            vpc_id: aws_vpc.vpc_id,
            service_name: endpoint.service_name,
            policy_document: if endpoint.policy then JSON.generate(Loader.policy(endpoint.policy)) end,
            route_table_ids: rt_ids(endpoint.route_tables)
          })
        end

        # Deleted endpoints
        endpoint_changes.removed.each do |endpoint_name, removed_diff|
          puts "Deleting endpoint #{endpoint_name}"
          @client.delete_vpc_endpoints({
            vpc_endpoint_ids: [removed_diff.aws.vpc_endpoint_id]
          })
        end

        # Modified endpoints
        endpoint_changes.modified.each do |endpoint_name, modified_diff|
          puts "Updating endpoint #{endpoint_name}"

          aws_endpoint = modified_diff.aws
          local_endpoint = modified_diff.local

          add_rt_ids = nil
          remove_rt_ids = nil

          modified_diff.changes.select { |d| d.type == EndpointChange::ROUTE_TABLES}.map do |endpoint_diff|
            if !endpoint_diff.changes.added.empty?
              add_rt_ids = rt_ids(endpoint_diff.changes.added)
            end

            if !endpoint_diff.changes.removed.empty?
              remove_rt_ids = rt_ids(endpoint_diff.changes.removed)
            end
          end

          @client.modify_vpc_endpoint({
            vpc_endpoint_id: aws_endpoint.vpc_endpoint_id,
            reset_policy: false,
            policy_document: if local_endpoint.policy then JSON.generate(Loader.policy(local_endpoint.policy)) end,
            add_route_table_ids: add_rt_ids,
            remove_route_table_ids: remove_rt_ids
          })
        end
      end

      def update_address_associations(aws_vpc, address_changes)
        # Added associations
        address_changes.added.each do |ip, addr_change|
          puts "Associating #{ip} to #{addr_change.local_name}"
          aws_address = EC2::public_addresses[ip]
          @client.associate_address({
            allow_reassociation: false, # This makes the operation fail if it was already associated
            allocation_id: aws_address.allocation_id,
            network_interface_id: addr_change.local.network_interface_id
          })
        end

        # Removed associations
        address_changes.removed.each do |ip, addr_change|
          puts "Disassociating #{ip} from #{addr_change.aws_name}"
          aws_address = EC2::public_addresses[ip]
          @client.disassociate_address({
            association_id: aws_address.association_id
          })
        end

        # Modified associations
        address_changes.modified.each do |ip, addr_change|
          puts "Changing association for #{ip} from #{addr_change.aws_name} to #{addr_change.local_name}"
          aws_address = EC2::public_addresses[ip]
          @client.associate_address({
            allow_reassociation: true, # We know it was associated to something else so allow reassociation
            allocation_id: aws_address.allocation_id,
            network_interface_id: addr_change.local.network_interface_id
          })
        end
      end

      def update_network_acls(aws_vpc, network_changes)
        # Added network acls
        network_changes.added.each do |acl_name, added_diff|
          puts "Creating Network ACL #{acl_name}"
          created_id = @client.create_network_acl({
            vpc_id: aws_vpc.vpc_id
          }).network_acl.network_acl_id

          acl_config = added_diff.local

          # Associate tags
          create_tags(created_id, acl_config.tags)

          # Create outbound entries
          acl_config.outbound.each do |entry|
            puts "Creating outbound entry with rule #{entry.rule}"
            create_network_acl_entry(created_id, entry, true)
          end

          # Create inbound entries
          acl_config.inbound.each do |entry|
            puts "Creating inbound entry with rule #{entry.rule}"
            create_network_acl_entry(created_id, entry, false)
          end
        end

        # Deleted network acls
        network_changes.removed.each do |acl_name, removed_diff|
          aws_acl = removed_diff.aws

          # Make sure the user isn't trying to delete the default acl
          if aws_acl.is_default
            puts Colors.red("Cannot delete the default Network ACL #{acl_name}")
          # Make sure there are no subnets associated with the acl
          elsif !aws_acl.associations.empty?
            puts Colors.red("Cannot delete a Network ACL with subnets associated to it")
          else
            puts "Deleting Network ACL #{acl_name}"
            @client.delete_network_acl({
              network_acl_id: aws_acl.network_acl_id
            })
          end

        end

        # Modified network acls
        network_changes.modified.each do |acl_name, modified_diff|
          acl_id = modified_diff.aws.network_acl_id

          modified_diff.changes.each do |net_acl_diff|
            case net_acl_diff.type
            when NetworkAclChange::OUTBOUND
              # Added outbound entries
              net_acl_diff.changes.added.each do |rule, added_entry_diff|
                puts "Creating outbound entry with rule #{rule}"
                create_network_acl_entry(acl_id, added_entry_diff.local, true)
              end

              # Removed outbound entries
              net_acl_diff.changes.removed.each do |rule, removed_entry_diff|
                puts "Removing outbound entry with rule #{rule}"
                delete_network_acl_entry(acl_id, rule, true)
              end

              # Modified outbound entries
              net_acl_diff.changes.modified.each do |rule, modified_entry_diff|
                puts "Updating outbound entry with rule #{rule}"
                replace_network_acl_entry(acl_id, modified_entry_diff.local, true)
              end
            when NetworkAclChange::INBOUND
              # Added inbound entries
              net_acl_diff.changes.added.each do |rule, added_entry_diff|
                puts "Creating inbound entry with rule #{rule}"
                create_network_acl_entry(acl_id, added_entry_diff.local, false)
              end

              # Removed outbound entries
              net_acl_diff.changes.removed.each do |rule, removed_entry_diff|
                puts "Removing outbound entry with rule #{rule}"
                delete_network_acl_entry(acl_id, rule, false)
              end

              # Modified outbound entries
              net_acl_diff.changes.modified.each do |rule, modified_entry_diff|
                puts "Updating outbound entry with rule #{rule}"
                replace_network_acl_entry(acl_id, modified_entry_diff.local, false)
              end
            when NetworkAclChange::TAGS
              if !net_acl_diff.tags_to_remove.empty?
                delete_tags(acl_id, net_acl_diff.tags_to_remove)
              end

              if !net_acl_diff.tags_to_add.empty?
                create_tags(acl_id, net_acl_diff.tags_to_add)
              end
            end
          end
        end
      end

      def create_network_acl_entry(network_acl_id, entry, egress)
        @client.create_network_acl_entry({
          network_acl_id: network_acl_id,
          rule_number: entry.rule,
          protocol: EC2::IPProtocolMapping.protocol(entry.protocol),
          rule_action: entry.action,
          egress: egress,
          cidr_block: entry.cidr_block,
          icmp_type_code:
            if entry.icmp_type || entry.icmp_code
              {
                type: entry.icmp_type,
                code: entry.icmp_code
              }
            end,
          port_range:
            if entry.ports
              from_port, to_port = entry.expand_ports
              {
                from: from_port,
                to: to_port
              }
            end
        })
      end

      def delete_network_acl_entry(network_acl_id, rule, egress)
        @client.delete_network_acl_entry({
          network_acl_id: network_acl_id,
          rule_number: rule,
          egress: egress
        })
      end

      def replace_network_acl_entry(network_acl_id, entry, egress)
        @client.replace_network_acl_entry({
          network_acl_id: network_acl_id,
          rule_number: entry.rule,
          protocol: EC2::IPProtocolMapping.protocol(entry.protocol),
          rule_action: entry.action,
          egress: egress,
          cidr_block: entry.cidr_block,
          icmp_type_code:
            if entry.icmp_type || entry.icmp_code
              {
                type: entry.icmp_type,
                code: entry.icmp_code
              }
            end,
          port_range:
            if entry.ports
              from_port, to_port = entry.expand_ports
              {
                from: from_port,
                to: to_port
              }
            end
        })
      end

      def update_subnets(aws_vpc, subnet_changes)
        # Refresh route tables so that the updated ones
        # (if any) can be associated with subnets
        EC2::refresh_route_tables!

        # Created subnets
        subnet_changes.added.each do |subnet_name, added_diff|
          puts "Creating subnet #{subnet_name}"

          subnet = added_diff.local

          # Create the subnet
          created_subnet = @client.create_subnet({
            vpc_id: aws_vpc.vpc_id,
            cidr_block: subnet.cidr_block,
            availability_zone: subnet.availability_zone
          }).subnet

          # Add tags
          if !subnet.tags.empty?
            create_tags(created_subnet.subnet_id, subnet.tags)
          end

          # Map public ip if needed
          if created_subnet.map_public_ip_on_launch != subnet.map_public_ip
            @client.modify_subnet_attribute({
              subnet_id: created_subnet.subnet_id,
              map_public_ip_on_launch: {
                value: subnet.map_public_ip
              }
            })
          end

          set_subnet_route_table(created_subnet.subnet_id, subnet.route_table)

          # Refresh network acls since a subnet is automatically associatd with the deafult one
          # and that association is needed to update it
          EC2::refresh_network_acls!
          set_subnet_network_acl(created_subnet.subnet_id, subnet.network_acl)
        end

        # Modified subnets
        subnet_changes.modified.each do |subnet_name, modified_diff|
          puts "Updating Subnet #{subnet_name}"
          local_subnet = modified_diff.local
          subnet_id = modified_diff.aws.subnet_id

          modified_diff.changes.each do |subnet_diff|
            case subnet_diff.type
            when SubnetChange::CIDR
              puts "Cannot update CIDR Block"
            when SubnetChange::AZ
              puts "Cannot update Availability Zone"
            when SubnetChange::ROUTE_TABLE
              puts "Updating Route Table"
              set_subnet_route_table(subnet_id, local_subnet.route_table)
            when SubnetChange::NETWORK_ACL
              puts "Updating Network ACL"
              set_subnet_network_acl(subnet_id, local_subnet.network_acl)
            when SubnetChange::TAGS
              puts "Updating Tags"
              if !subnet_diff.tags_to_remove.empty?
                delete_tags(subnet_id, subnet_diff.tags_to_remove)
              end

              if !subnet_diff.tags_to_add.empty?
                create_tags(subnet_id, subnet_diff.tags_to_add)
              end
            end
          end
        end
      end

      def set_subnet_route_table(subnet_id, rt_name)
        # Get the association for the subnet
        aws_rt = EC2::subnet_route_tables[subnet_id]
        association_id = if aws_rt and !aws_rt.associations.empty?
          subnet_assoc = aws_rt.associations.select { |assoc| assoc.subnet_id = subnet_id }.first
          if subnet_assoc
            subnet_assoc.route_table_association_id
          end
        end

        rt_id = if rt_name then EC2::named_route_tables[rt_name].route_table_id end

        if association_id
          # If there was an association then replace or disassociate
          if rt_id
            # Replace
            @client.replace_route_table_association({
              association_id: association_id,
              route_table_id: rt_id
            })
          else
            # Disassociate
            @client.disassociate_route_table({
              association_id: association_id
            })
          end
        elsif rt_id
          # Create a new association
          @client.associate_route_table({
            subnet_id: subnet_id,
            route_table_id: rt_id
          })
        end

      end

      def set_subnet_network_acl(subnet_id, acl_name)
        # Get the association for the subnet
        association_id = EC2::subnet_network_acls[subnet_id].associations.select { |assoc| assoc.subnet_id = subnet_id }.first.network_acl_association_id
        acl_id = EC2::named_network_acls[acl_name].network_acl_id

        @client.replace_network_acl_association({
          association_id: association_id,
          network_acl_id: acl_id
        })
      end

    end
  end
end
