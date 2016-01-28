require "autoscaling/AutoScaling"
require "common/manager/Manager"
require "conf/Configuration"
require "ec2/EC2"
require "ec2/loaders/InstanceLoader"
require "ec2/models/InstanceConfig"
require "ec2/models/InstanceDiff"
require "iam/IAM"
require "util/StatusCodes"

require "aws-sdk"
require "base64"

module Cumulus
  module EC2
    class InstanceManager < Common::Manager

      def initialize
        super()
        @create_asset = true
        @client = Aws::EC2::Client.new(Configuration.instance.client)
        @device_name_base = Configuration.instance.ec2.volume_mount_base
        @device_name_start = Configuration.instance.ec2.volume_mount_start
        @device_name_end = Configuration.instance.ec2.volume_mount_end
      end

      def resource_name
        "EC2 Instance"
      end

      def local_resources
        @local_resources ||= Hash[InstanceLoader.instances.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||=
          EC2::named_instances
            .reject { |name, i| AutoScaling::instance_ids.include?(i.instance_id) }
            .select { |name, i| !Configuration.instance.ec2.ignore_unmanaged_instances || local_resources.has_key?(name) }
      end

      def unmanaged_diff(aws)
        InstanceDiff.unmanaged(aws)
      end

      def added_diff(local)
        InstanceDiff.added(local)
      end

      def diff_resource(local, aws)
        instance_attributes = EC2::id_instance_attributes(aws.instance_id)
        user_data_file = InstanceLoader.user_data_base64.key(instance_attributes.user_data)
        cumulus_version = InstanceConfig.new(local.name).populate!(aws, user_data_file, instance_attributes.tags)

        local.diff(cumulus_version)
      end

      def migrate
        puts Colors.blue("Migrating Instances...")

        # Create the directories
        ec2_dir = "#{@migration_root}/ec2"
        instances_dir = "#{ec2_dir}/instances"
        user_data_dir = "#{ec2_dir}/user-data-scripts"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(ec2_dir)
          Dir.mkdir(ec2_dir)
        end
        if !Dir.exists?(instances_dir)
          Dir.mkdir(instances_dir)
        end
        if !Dir.exists?(user_data_dir)
          Dir.mkdir(user_data_dir)
        end

        # Only migrate instances not in an autoscaling group
        migratable_instances = EC2::named_instances.reject { |name, i| AutoScaling::instance_ids.include?(i.instance_id) }
        puts "Will migrate #{migratable_instances.length} instances"

        migratable_instances.each do |name, instance|
          puts "Migrating #{name}..."

          instance_attributes = EC2::id_instance_attributes(instance.instance_id)

          # If there was user data set, migrate that too
          if instance_attributes.user_data
            user_data_file = "#{name}.sh"
            file_location = "#{user_data_dir}/#{user_data_file}"
            puts "Migrating user data script to #{file_location}"
            file_contents = Base64.decode64(instance_attributes.user_data)
            File.open(file_location, "w") { |f| f.write(file_contents) }
          end

          cumulus_instance = InstanceConfig.new(name).populate!(instance, user_data_file, instance_attributes.tags)

          json = JSON.pretty_generate(cumulus_instance.to_hash)
          File.open("#{instances_dir}/#{name}.json", "w") { |f| f.write(json) }
        end

      end

      def create(local)
        #######################################
        # Make sure required attributes are set
        #######################################

        # Check for image
        errors = []
        image_id = local.image || Configuration.instance.ec2.default_image_id
        if image_id.nil?
          errors << "image is required"
        end

        # Check for IAM profile
        profile_arn = if local.profile.nil?
          errors << "profile is required"
          nil
        else
          arn = IAM::get_instance_profile_arn(local.profile)
          if arn.nil?
            errors << "no profile named #{local.profile} exists"
          end
          arn
        end

        # Check for security groups
        if local.security_groups.empty?
          errors << "security-groups is required"
        end

        # Check for subnet
        if local.subnet.nil?
          errors << "subnet is required"
        end

        aws_subnet = EC2::named_subnets[local.subnet]
        if aws_subnet.nil?
          errors << "subnet #{local.subnet} does not exist"
        end

        # Get the vpc id from the subnet
        vpc_id = aws_subnet.vpc_id

        security_group_ids = local.security_groups.map do |sg|
          sg_id = SecurityGroups.vpc_security_group_id_names[vpc_id].key(sg)
          if sg_id.nil?
            errors << "security group #{sg} does not exist"
          end
          sg_id
        end

        # Check for type
        if local.type.nil?
          errors << "type is required"
        end

        # Make sure the placement group exists
        if !local.placement_group.nil? and EC2::named_placement_groups[local.placement_group].nil?
          errors << "placement group #{local.placement_group} does not exist"
        end

        availability_zone = if aws_subnet then aws_subnet.availability_zone end

        # Check for volume groups
        volumes = if !local.volume_groups.empty?
          # Try to get the volumes for each volume group, make sure they are in the right AZ
          local.volume_groups.map do |vg|
            vols = EC2::group_ebs_volumes_aws[vg]
            if vols.nil?
              errors << "volume group #{vg} does not exist"
            elsif vols.empty?
              errors << "could not find volumes for group #{vg}"
            else
              if availability_zone and vols.any? { |vol| vol.availability_zone != availability_zone }
                errors << "not all volumes in #{vg} are in the correct availability zone: #{availability_zone}"
              end
            end
            vols
          end.flatten
        else
          puts "Warning: Only the root volume will be attached to the instance"
          []
        end

        # Make sure there are not more volumes than device names for volumes
        if (@device_name_end.ord - @device_name_start.ord + 1) < volumes.length
          errors << "cannot attach more volumes than there are names for between #{@device_name_base}#{@device_name_start} and #{@device_name_base}#{@device_name_end}"
        end

        if !errors.empty?
          puts "Could not create #{local.name}:"
          errors.each { |e| puts "\t#{e}"}
          exit StatusCodes::EXCEPTION
        end

        created_instance = @client.run_instances({
          image_id: image_id,
          min_count: 1,
          max_count: 1,
          key_name: local.key_name,
          security_group_ids: if local.network_interfaces == 0 then security_group_ids end,
          user_data: if local.user_data then Base64.encode64(InstanceLoader.user_data(local.user_data)) end,
          instance_type: local.type,
          subnet_id: if local.network_interfaces == 0 then aws_subnet.subnet_id end,
          placement: {
            availability_zone: availability_zone,
            group_name: local.placement_group,
            tenancy: local.tenancy,
          },
          monitoring: {
            enabled: local.monitoring
          },
          private_ip_address: if local.network_interfaces == 0 then local.private_ip_address end,
          network_interfaces: Array.new(local.network_interfaces) do |index|
            {
              subnet_id: aws_subnet.subnet_id,
              groups: security_group_ids,
              delete_on_termination: true,
              device_index: index,
              private_ip_addresses: if local.network_interfaces == 1 and local.private_ip_address
                [
                  {
                    private_ip_address: local.private_ip_address,
                    primary: true
                  }
                ]
              end
            }
          end,
          iam_instance_profile: {
            arn: profile_arn
          },
          ebs_optimized: local.ebs_optimized
        }).instances.first

        # Wait until the instance is running then attach volumes
        print "Waiting for instance to run"
        @client.wait_until(:instance_running, {
          instance_ids: [created_instance.instance_id]
        }) do |waiter|
          waiter.before_wait { print "." }
        end
        puts ""

        if !local.tags.empty?
          set_tags(created_instance.instance_id, local.tags)
        end
        set_name(created_instance.instance_id, local.name)

        if created_instance.source_dest_check != local.source_dest_check
          set_instance_source_dest_check(created_instance.instance_id, local.source_dest_check)
        end

        # If there are multiple network interfaces, source dest check must be set on each one
        if created_instance.network_interfaces.length > 1
          created_instance.network_interfaces.each do |interface|
            set_interface_source_dest_check(interface.network_interface_id, local.source_dest_check)
          end
        else
          set_instance_source_dest_check(created_instance.instance_id, local.source_dest_check)
        end

        # Attach volume groups
        attach_volumes(created_instance.instance_id, volumes, @device_name_start)

      end

      def update(local, diffs)
        aws_instance = EC2::named_instances[local.name]

        diffs.each do |diff|
          case diff.type
          when  InstanceChange::PROFILE,
                InstanceChange::SUBNET,
                InstanceChange::TYPE,
                InstanceChange::TENANCY

            puts Colors.red("Cannot change #{diff.asset_type}")
          when InstanceChange::EBS
            if !aws_instance.stopped?
              puts Colors.red("Cannot update EBS Optimized unless the instance is stopped")
            else
              puts "Setting EBS Optimized to #{local.ebs_optimized}..."
              set_ebs_optimized(aws_instance.instance_id, local.ebs_optimized)
            end
          when InstanceChange::MONITORING
            if local.monitoring
              puts "Enabling monitoring..."
              set_monitoring(aws_instance.instance_id, true)
            else
              puts "Disabling monitoring..."
              set_monitoring(aws_instance.instance_id, false)
            end
          when InstanceChange::SECURITY_GROUPS
            puts "Updating Security Groups..."

            # If there are multiple network interfaces, security groups must be set on each one
            if aws_instance.network_interfaces.length > 1
              aws_instance.network_interfaces.each do |interface|
                set_interface_security_groups(aws_instance.vpc_id, interface.network_interface_id, local.security_groups)
              end
            else
              set_instance_security_groups(aws_instance.vpc_id, aws_instance.instance_id, local.security_groups)
            end

          when InstanceChange::SDCHECK
            puts "Setting Source Dest Check to #{local.source_dest_check}..."

            # If there are multiple network interfaces, source dest check must be set on each one
            if aws_instance.network_interfaces.length > 1
              aws_instance.network_interfaces.each do |interface|
                set_interface_source_dest_check(interface.network_interface_id, local.source_dest_check)
              end
            else
              set_instance_source_dest_check(aws_instance.instance_id, local.source_dest_check)
            end
          when InstanceChange::INTERFACES
            if diff.aws > diff.local
              puts Colors.red("Cumulus will not detach or delete network interfaces. You must do so manually and update the config")
            else
              # Figure out highest device index for current interfaces
              highest_device_index = (aws_instance.network_interfaces.map(&:attachment).map(&:device_index).max || 0) + 1

              (diff.local - diff.aws).times do |i|
                puts "Creating network interface..."
                interface_id = create_network_interface(aws_instance.vpc_id, aws_instance.subnet_id, local.security_groups)
                set_interface_source_dest_check(interface_id, local.source_dest_check)

                puts "Attaching network interface..."
                attachment_id = attach_network_interface(aws_instance.instance_id, interface_id, highest_device_index + i)
                set_delete_on_terminate(interface_id, attachment_id)
              end
            end
          when InstanceChange::VOLUME_GROUPS
            # Figure out the highest device name for already attached volumes
            last_device_name = aws_instance.nonroot_devices.map(&:device_name).sort.last
            start_attaching_at = if last_device_name then (last_device_name[-1].ord + 1).chr else @start_device_letter end

            # Figure out which volumes in the group are not attached
            volumes_to_attach = diff.local.map { |group_name, group_config| EC2::group_ebs_volumes_aws[group_name] }.flatten.select(&:detached?)

            # Make sure there are not more volumes than device names for volumes
            if start_attaching_at.ord > @device_name_end.ord
              puts Colors.red("Cannot attach volumes past #{@device_name_base}#{@device_name_end}")
            elsif (@device_name_end.ord - start_attaching_at.ord + 1) < volumes_to_attach.length
              puts Colors.red("Cannot attach more volumes than there are names for between #{@device_name_base}#{start_attaching_at} and #{@device_name_base}#{@device_name_end}")
            else
              attach_volumes(aws_instance.instance_id, volumes_to_attach, start_attaching_at)
            end
          when InstanceChange::TAGS
            puts "Updating tags..."

            if !diff.tags_to_remove.empty?
              delete_tags(aws_instance.instance_id, diff.tags_to_remove)
            end

            if !diff.tags_to_add.empty?
              set_tags(aws_instance.instance_id, diff.tags_to_add)
            end

          end
        end
      end

      private

      def set_name(instance_id, name)
        @client.create_tags({
          resources: [instance_id],
          tags: [
            {
              key: "Name",
              value: name
            }
          ]
        })
      end

      def set_tags(instance_id, tags)
        @client.create_tags({
          resources: [instance_id],
          tags: tags.map do |key, val|
            {
              key: key,
              value: val
            }
          end
        })
      end

      def delete_tags(instance_id, tags)
        @client.delete_tags({
          resources: [instance_id],
          tags: tags.map do |key, val|
            {
              key: key,
              value: val
            }
          end
        })
      end

      def set_instance_source_dest_check(instance_id, source_dest_check)
        @client.modify_instance_attribute({
          instance_id: instance_id,
          source_dest_check: {
            value: source_dest_check
          }
        })
      end

      def set_interface_source_dest_check(interface_id, source_dest_check)
        @client.modify_network_interface_attribute({
          network_interface_id: interface_id,
          source_dest_check: {
            value: source_dest_check
          }
        })
      end

      def set_ebs_optimized(instance_id, optimized)
        @client.modify_instance_attribute({
          instance_id: instance_id,
          ebs_optimized: {
            value: optimized
          }
        })
      end

      def set_instance_security_groups(vpc_id, instance_id, sg_names)
        @client.modify_instance_attribute({
          instance_id: instance_id,
          groups: sg_names.map { |sg| SecurityGroups.vpc_security_group_id_names[vpc_id].key(sg) }
        })
      end

      def set_interface_security_groups(vpc_id, interface_id, sg_names)
        @client.modify_network_interface_attribute({
          network_interface_id: interface_id,
          groups: sg_names.map { |sg| SecurityGroups.vpc_security_group_id_names[vpc_id].key(sg) }
        })
      end

      def set_monitoring(instance_id, monitoring)
        if monitoring
          @client.monitor_instances({
            instance_ids: [instance_id]
          })
        else
          @client.unmonitor_instances({
            instance_ids: [instance_id]
          })
        end
      end

      def create_network_interface(vpc_id, subnet_id, sg_names)
        @client.create_network_interface({
          subnet_id: subnet_id,
          groups: sg_names.map { |sg| SecurityGroups.vpc_security_group_id_names[vpc_id].key(sg) }
        }).network_interface.network_interface_id
      end

      def attach_network_interface(instance_id, interface_id, device_index)
        @client.attach_network_interface({
          network_interface_id: interface_id,
          instance_id: instance_id,
          device_index: device_index
        }).attachment_id
      end

      def set_delete_on_terminate(interface_id, attachment_id)
        @client.modify_network_interface_attribute({
          network_interface_id: interface_id,
          attachment: {
            attachment_id: attachment_id,
            delete_on_termination: true
          }
        })
      end

      def attach_volumes(instance_id, volumes, start_device_letter)

        device_letter = start_device_letter

        # sort volumes by size then map to id
        volume_ids = volumes.sort_by(&:size).map(&:volume_id)

        volume_ids.each do |vol_id|
          device_name = "#{@device_name_base}#{device_letter}"
          puts "Attaching volume to #{device_name}..."

          @client.attach_volume({
            instance_id: instance_id,
            volume_id: vol_id,
            device: device_name
          })

          device_letter = (device_letter.ord + 1).chr
        end

      end

    end
  end
end