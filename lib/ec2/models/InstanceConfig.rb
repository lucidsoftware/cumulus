require "common/models/ListChange"
require "conf/Configuration"
require "ec2/models/EbsGroupConfig"
require "ec2/models/EbsGroupDiff"
require "ec2/models/InstanceDiff"
require "ec2/EC2"
require "security/SecurityGroups"

require "json"

module Cumulus
  module EC2

    # Public: An object representing configuration for a network interface
    class InstanceConfig
      attr_reader :name
      attr_reader :ebs_optimized
      attr_reader :placement_group
      attr_reader :profile
      attr_reader :image
      attr_reader :key_name
      attr_reader :monitoring
      attr_reader :network_interfaces
      attr_reader :source_dest_check
      attr_reader :private_ip_address
      attr_reader :security_groups
      attr_reader :subnet
      attr_reader :tenancy
      attr_reader :type
      attr_reader :user_data
      attr_reader :volume_groups
      attr_reader :tags

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the group
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @ebs_optimized = json["ebs-optimized"] || false
          @placement_group = json["placement-group"]
          @profile = json["profile"]
          @image = json["image"]
          @key_name = json["key-name"]
          @monitoring = json["monitoring"] || false
          @network_interfaces = json["network-interfaces"] || 0
          @source_dest_check = json["source-dest-check"]
          @private_ip_address = json["private-ip-address"]
          @security_groups = json["security-groups"] || []
          @subnet = json["subnet"]
          @tenancy = json["tenancy"] || "default"
          @type = json["type"]
          @user_data = json["user-data"]
          @volume_groups = json["volume-groups"] || []
          @tags = json["tags"] || {}
        end
      end

      def to_hash
        {
          "ebs-optimized" => @ebs_optimized,
          "placement-group" => @placement_group,
          "profile" => @profile,
          "image" => @image,
          "key-name" => @key_name,
          "monitoring" => @monitoring,
          "network-interfaces" => @network_interfaces,
          "source-dest-check" => @source_dest_check,
          "private-ip-address" => @private_ip_address,
          "security-groups" => @security_groups,
          "subnet" => @subnet,
          "tenancy" => @tenancy,
          "type" => @type,
          "user-data" => @user_data,
          "volume-groups" => @volume_groups,
          "tags" => @tags,
        }
      end

      # Public: Populate a config object with AWS configuration
      #
      # aws_instance - the instance from AWS
      # user_data_file - the name of the user data script file
      # tags - a Hash of tags for the instance
      def populate!(aws_instance, user_data_file, tags)
        @ebs_optimized = aws_instance.ebs_optimized
        @placement_group = aws_instance.placement.group_name
        if @placement_group.empty? then @placement_group = nil end

        profile_arn = (aws_instance.iam_instance_profile.arn rescue nil)
        @profile = if profile_arn then profile_arn[profile_arn.rindex("/") + 1 .. profile_arn.length] end

        @image = aws_instance.image_id
        @key_name = aws_instance.key_name
        @monitoring = ["enabled", "pending"].include? aws_instance.monitoring.state
        @network_interfaces = aws_instance.network_interfaces.length
        @source_dest_check = aws_instance.source_dest_check
        @private_ip_address = aws_instance.private_ip_address
        @security_groups = aws_instance.security_groups.map(&:group_id).map { |id| SecurityGroups::id_security_groups[id].group_name }.sort
        @subnet = EC2::id_subnets[aws_instance.subnet_id].name
        @tenancy = aws_instance.placement.tenancy
        @type = aws_instance.instance_type
        @user_data = user_data_file

        # Get the volumes for each device mapping
        @volume_groups = aws_instance.nonroot_devices.map do |m|
          EC2::id_ebs_volumes[m.ebs.volume_id]
        end.map(&:group).reject(&:nil?).uniq.sort

        @tags = tags

        self
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the InterfaceDiffs that were found
      def diff(aws)
        diffs = []

        if aws.ebs_optimized != @ebs_optimized
          diffs << InstanceDiff.new(InstanceChange::EBS, aws.ebs_optimized, @ebs_optimized)
        end

        if aws.profile != @profile
          diffs << InstanceDiff.new(InstanceChange::PROFILE, aws.profile, @profile)
        end

        if aws.monitoring != @monitoring
          diffs << InstanceDiff.new(InstanceChange::MONITORING, aws.monitoring, @monitoring)
        end

        if aws.network_interfaces != @network_interfaces
          diffs << InstanceDiff.new(InstanceChange::INTERFACES, aws.network_interfaces, @network_interfaces)
        end

        if aws.source_dest_check != @source_dest_check
          diffs << InstanceDiff.new(InstanceChange::SDCHECK, aws.source_dest_check, @source_dest_check)
        end

        if aws.security_groups.sort != @security_groups.sort
          changes = Common::ListChange::simple_list_diff(aws.security_groups, @security_groups)
          diffs << InstanceDiff.new(InstanceChange::SECURITY_GROUPS, aws.security_groups, @security_groups, changes)
        end

        if aws.subnet != @subnet
          diffs << InstanceDiff.new(InstanceChange::SUBNET, aws.subnet, @subnet)
        end

        if aws.type != @type
          diffs << InstanceDiff.new(InstanceChange::TYPE, aws.type, @type)
        end

        if aws.tenancy != @tenancy
          diffs << InstanceDiff.new(InstanceChange::TENANCY, aws.tenancy, @tenancy)
        end

        if aws.tags != @tags
          diffs << InstanceDiff.new(InstanceChange::TAGS, aws.tags, @tags)
        end

        # Check for diffs in volume groups and diffs in how many volumes are attached

        # Get the volumes that are attached to the instance
        aws_instance = EC2::named_instances[aws.name]
        attached_volumes = aws_instance.nonroot_devices.map do |m|
          EC2::id_ebs_volumes[m.ebs.volume_id]
        end
        # Group by volume group, reject nil groups
        group_volumes = attached_volumes.group_by(&:group).reject { |k, v| k.nil? }

        aws_ebs_groups = Hash[group_volumes.map { |group, vols| [group, EbsGroupConfig.new(group).populate!(vols)] }]
        local_ebs_groups = Hash[@volume_groups.map { |vg| [vg, EC2::group_ebs_volumes[vg]] }]

        added_groups = Hash[local_ebs_groups.reject { |k, v| aws_ebs_groups.has_key?(k) }.map do |group_name, group_config|
          [group_name, EbsGroupDiff.added(group_config)]
        end]
        removed_groups = Hash[aws_ebs_groups.reject { |k, v| aws_ebs_groups.has_key?(k) }.map do |group_name, group_config|
          [group_name, EbsGroupDiff.unmanaged(group_config)]
        end]
        changed_groups = Hash[local_ebs_groups.select { |k, v| aws_ebs_groups.has_key?(k) }.map do |group_name, group_config|
          aws_config = aws_ebs_groups[group_name]
          group_diffs = group_config.diff(aws_config)
          if !group_diffs.empty?
            [group_name, EbsGroupDiff.modified(aws_config, group_config, group_diffs)]
          end
        end.reject { |v| v.nil? }]

        ebs_changes = Common::ListChange.new(added_groups, removed_groups, changed_groups)
        if !ebs_changes.empty?
          diffs << InstanceDiff.new(InstanceChange::VOLUME_GROUPS, aws_ebs_groups, local_ebs_groups, ebs_changes)
        end

        diffs
      end

    end
  end
end
