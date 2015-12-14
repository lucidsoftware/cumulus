require "common/manager/Manager"
require "conf/Configuration"
require "ec2/EC2"
require "ec2/loaders/EbsLoader"
require "ec2/models/EbsGroupConfig"
require "ec2/models/EbsGroupDiff"
require "util/StatusCodes"

require "aws-sdk"

module Cumulus
  module EC2
    class EbsManager < Common::Manager

      def initialize
        super()
        @create_asset = true
        @client = Aws::EC2::Client.new(Configuration.instance.client)
      end

      def resource_name
        "EBS Volume Group"
      end

      def local_resources
        @local_resources ||= Hash[EbsLoader.groups.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= EC2::group_ebs_volumes
      end

      def unmanaged_diff(aws)
        EbsGroupDiff.unmanaged(aws)
      end

      def added_diff(local)
        EbsGroupDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      EbsMigrationData = Struct.new(:cumulus_group, :set_group_vols)
      def migrate
        puts Colors.blue("Migrating EBS Volume Groups...")

        # Create the directories
        ec2_dir = "#{@migration_root}/ec2"
        ebs_dir = "#{ec2_dir}/ebs"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(ec2_dir)
          Dir.mkdir(ec2_dir)
        end
        if !Dir.exists?(ebs_dir)
          Dir.mkdir(ebs_dir)
        end

        puts "Would you like Cumulus to automatically update your volumes to have a Group tag that matches the name of the instance they are attached to? (y/n)"
        update_tags = (STDIN.getc.downcase[0] == "y")

        # Migrate any volumes that have already been grouped
        vol_groups = Hash[EC2.group_ebs_volumes.map { |group_name, cumulus_group| [group_name, EbsMigrationData.new(cumulus_group, nil)] }]

        # Use the instance name to group volumes if they do not have a group.  Anything
        # not attached should not get migrated
        migratable_vols = EC2.ebs_volumes.select { |vol| vol.group.nil? and !vol.attachments.empty? and vol.attached? }
        instance_grouped = migratable_vols.group_by do |vol|
          attachments = vol.attachments.select { |att| att.state == "attached" || att.state == "attaching" }
          attachments.first.instance_id
        end

        instance_grouped.each do |instance_id, vols|
          instance_name = EC2.id_instances[instance_id].name || instance_id
          vol_groups[instance_name] = EbsMigrationData.new(EbsGroupConfig.new(instance_name).populate!(vols), vols)
        end

        vol_groups.each do |group_name, data|
          puts "Migrating group #{group_name}"

          if update_tags and data.set_group_vols
            data.set_group_vols.each do |vol|
              if vol.group.nil?
                set_group_name(vol.volume_id, group_name)
              end
            end
          end

          json = JSON.pretty_generate(data.cumulus_group.to_hash)
          File.open("#{ebs_dir}/#{group_name}.json", "w") { |f| f.write(json) }
        end

      end

      def create(local)
        local.volume_groups.each do |vg|
          vg.count.times do
            create_volume(vg, local.availability_zone, local.name)
          end
        end
      end

      def update(local, diffs)

        # If they tried to update AZ, use the old value
        availability_zone = (diffs.select { |d| d.type == EbsGroupChange::AZ }.first.aws rescue local.availability_zone)

        diffs.each do |diff|
          case diff.type
          when EbsGroupChange::AZ
            puts Colors.blue("Availability zone cannot be updated")
          when EbsGroupChange::VG_REMOVED
            puts Colors.blue("Cumulus does not delete or detach volumes. Manually update #{diff.local.description}")
          when EbsGroupChange::VG_ADDED
            added_vg = diff.local
            puts Colors.blue("Creating #{added_vg.count} x #{added_vg.description}...")
            added_vg.count.times do
              create_volume(added_vg, availability_zone, local.name)
            end
          when EbsGroupChange::VG_COUNT
            if diff.local.count < diff.aws.count
              puts Colors.blue("Cumulus will not delete or detach volumes. Manually update #{diff.local.description}")
            else
              num_added = diff.local.count - diff.aws.count
              puts Colors.blue("Adding #{num_added} x #{diff.local.description}...")
              num_added.times do
                create_volume(diff.local, availability_zone, local.name)
              end
            end
          end
        end
      end

      private

      # Internal: Sets the Group tag for an ebs volume
      def set_group_name(volume_id, group_name)
        @client.create_tags({
          resources: [volume_id],
          tags: [
            {
              key: "Group",
              value: group_name
            }
          ]
        })
      end

      # Internal: Creates a volume then sets the group name
      #
      # vg - the VolumeGroup config to use for volume attributes
      # az - the availability zone to create the volume in
      # group_name - the name of the group the volume belongs to
      def create_volume(vg, az, group_name)
        resp = @client.create_volume({
          size: vg.size,
          availability_zone: az,
          volume_type: vg.type,
          iops: vg.iops,
          encrypted: vg.encrypted,
          kms_key_id: vg.kms_key
        })

        set_group_name(resp.volume_id, group_name)
      rescue => e
        puts "Failed to create a volume of #{vg.description}: #{e}"
        exit StatusCodes.EXCEPTION
      end

    end
  end
end