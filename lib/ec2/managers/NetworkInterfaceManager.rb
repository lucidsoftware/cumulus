require "common/manager/Manager"
require "conf/Configuration"
require "ec2/EC2"
require "ec2/loaders/NetworkInterfaceLoader"
require "ec2/models/InterfaceConfig"
require "ec2/models/InterfaceDiff"
require "security/SecurityGroups"

require "aws-sdk"

module Cumulus
  module EC2
    class NetworkInterfaceManager < Common::Manager

      def initialize
        super()
        @create_asset = true
        @client = Aws::EC2::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)
      end

      def resource_name
        "Network Interface"
      end

      def local_resources
        @local_resources ||= Hash[NetworkInterfaceLoader.interfaces.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= Hash[EC2::named_network_interfaces.map { |name, aws_interface| [name, InterfaceConfig.new(name).populate!(aws_interface)] }]
      end

      def unmanaged_diff(aws)
        InterfaceDiff.unmanaged(aws)
      end

      def added_diff(local)
        InterfaceDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      def migrate
        puts Colors.blue("Migrating Network Interfaces...")

        # Create the directories
        ec2_dir = "#{@migration_root}/ec2"
        net_dir = "#{ec2_dir}/network-interfaces"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(ec2_dir)
          Dir.mkdir(ec2_dir)
        end
        if !Dir.exists?(net_dir)
          Dir.mkdir(net_dir)
        end

        EC2::named_network_interfaces.each do |name, interface|
          puts "Migrating network interface #{name}"

          cumulus_interface = InterfaceConfig.new(name).populate!(interface)
          json = JSON.pretty_generate(cumulus_interface.to_hash)
          File.open("#{net_dir}/#{name}.json", "w") { |f| f.write(json) }
        end

      end

      def create(local)
        subnet_id = EC2::named_subnets[local.subnet].subnet_id
        group_ids = local.groups.map { |group| SecurityGroups::sg_id_names.key(group) }

        created_interface = @client.create_network_interface({
          subnet_id: subnet_id,
          description: local.description,
          groups: group_ids,
        }).network_interface

        if created_interface.source_dest_check != local.source_dest_check
          set_source_dest(created_interface.network_interface_id,  local.source_dest_check)
        end

        set_name(created_interface.network_interface_id, local.name)

      end

      def update(local, diffs)
        interface_id = EC2::named_network_interfaces[local.name].network_interface_id

        diffs.each do |diff|
          case diff.type
          when InterfaceChange::SUBNET
            puts Colors.red("Subnet cannot be updated")
          when InterfaceChange::DESCRIPTION
            puts Colors.blue("Updating description...")
            set_description(interface_id, local.description)
          when InterfaceChange::SDCHECK
            puts Colors.blue("Updating source dest check...")
            set_source_dest(interface_id, local.source_dest_check)
          when InterfaceChange::GROUPS
            puts Colors.blue("Updating security groups...")
            group_ids = local.groups.map { |group| SecurityGroups::sg_id_names.key(group) }
            set_groups(interface_id, group_ids)
          end
        end
      end

      private

      # Internal: Sets the Name tag for an interface
      def set_name(interface_id, name)
        @client.create_tags({
          resources: [interface_id],
          tags: [
            {
              key: "Name",
              value: name
            }
          ]
        })
      end

      # Internal: Sets the description for an interface
      def set_description(interface_id, description)
        @client.modify_network_interface_attribute({
          network_interface_id: interface_id,
          description:
            {
              value: description
            }
        })
      end

      # Internal: Sets the source dest check for an interface
      def set_source_dest(interface_id, sd_check)
        @client.modify_network_interface_attribute({
          network_interface_id: interface_id,
          source_dest_check:
            {
              value: sd_check
            }
        })
      end

      # Internal: Sets the security groups for an interface
      def set_groups(interface_id, groups)
        @client.modify_network_interface_attribute({
          network_interface_id: interface_id,
          groups: groups
        })
      end

    end
  end
end