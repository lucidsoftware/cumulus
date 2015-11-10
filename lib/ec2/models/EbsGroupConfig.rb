require "conf/Configuration"
require "ec2/models/EbsGroupDiff"

require "json"

module Cumulus
  module EC2

    VolumeGroup = Struct.new(:size, :type, :iops, :count, :encrypted, :kms_key) do
      def to_hash
        {
          "size" => self.size,
          "type" => self.type,
          "iops" => self.iops,
          "count" => self.count,
          "encrypted" => self.encrypted,
          "kms-key" => self.kms_key
        }.reject { |k, v| v.nil? }
      end

      def description
        [
          "#{self.size}GiB",
          "#{self.type}",
          if self.type == "io1" then "#{self.iops} IOPS" end,
          if self.encrypted then "encrypted" else "unencrypted" end,
          if self.kms_key then "KMS #{self.kms_key}" end,
        ].reject(&:nil?).join("/")
      end

      def hash_key
        "#{self.size}|#{self.type}|#{self.iops}|#{self.encrypted}|#{self.kms_key}"
      end
    end

    # Public: An object representing configuration for a group of EBS volumes
    class EbsGroupConfig
      attr_reader :name
      attr_reader :volume_groups
      attr_reader :availability_zone

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the group
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @availability_zone = json["availability-zone"]
          @volume_groups = (json["volumes"] || []).map do |vg_json|
            VolumeGroup.new(
              vg_json["size"],
              vg_json["type"],
              if vg_json["type"] == "io1" then vg_json["iops"] end,
              vg_json["count"],
              vg_json["encrypted"] || false,
              if vg_json["encrypted"] then vg_json["kms-key"] end
            )
          end
        end
      end

      def to_hash
        {
          "availability-zone" => @availability_zone,
          "volumes" => @volume_groups.map(&:to_hash),
        }
      end

      # Public: Populate a config object with AWS configuration
      #
      # aws - the ebs volumes in the group. All volumes should be in the same AZ
      def populate!(aws)
        # Group the aws volumes by size, type, iops, encryped, kms-key
        vol_groups = aws.group_by { |vol| "#{vol.size}|#{vol.volume_type}|#{vol.iops}|#{vol.encrypted}|#{vol.kms_key_id}" }

        @volume_groups = vol_groups.map do |_, vols|
          VolumeGroup.new(
            vols.first.size,
            vols.first.volume_type,
            if vols.first.volume_type == "io1" then vols.first.iops end,
            vols.length,
            vols.first.encrypted,
            vols.first.kms_key_id
          )
        end

        # Get the AZ of the first volume
        @availability_zone = aws.first.availability_zone

        self
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the EbsGroupDiffs that were found
      def diff(aws)
        diffs = []

        if @availability_zone != aws.availability_zone
          diffs << EbsGroupDiff.new(EbsGroupChange::AZ, aws.availability_zone, @availability_zone)
        end

        # Group the aws and local versions by hash_key
        aws_grouped = Hash[aws.volume_groups.map { |vg| [vg.hash_key, vg] }]
        local_grouped = Hash[@volume_groups.map { |vg| [vg.hash_key, vg] }]

        # added
        local_grouped.reject { |key, vg| aws_grouped.has_key? key }.each do |key, vg|
          diffs << EbsGroupDiff.new(EbsGroupChange::VG_ADDED, nil, vg)
        end

        # removed
        aws_grouped.reject { |key, vg| local_grouped.has_key? key }.each do |key, vg|
          diffs << EbsGroupDiff.new(EbsGroupChange::VG_REMOVED, vg, nil)
        end

        # count is different
        local_grouped.select { |key, vg| aws_grouped.has_key? key }.each do |key, local_vg|
          aws_vg = aws_grouped[key]
          if local_vg.count != aws_vg.count
            diffs << EbsGroupDiff.new(EbsGroupDiff::VG_COUNT, aws_vg, local_vg)
          end
        end

        diffs.sort_by { |diff| diff.type }
      end

    end
  end
end
