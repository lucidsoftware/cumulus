require "common/models/Diff"
require "util/Colors"

require 'json'

module Cumulus
  module EC2
    # Public: The types of changes that can be made to an EBS volume group
    module InstanceChange
      include Common::DiffChange

      EBS = Common::DiffChange.next_change_id
      PROFILE = Common::DiffChange.next_change_id
      MONITORING = Common::DiffChange.next_change_id
      INTERFACES = Common::DiffChange.next_change_id
      SDCHECK = Common::DiffChange.next_change_id
      SECURITY_GROUPS = Common::DiffChange.next_change_id
      SUBNET = Common::DiffChange.next_change_id
      TYPE = Common::DiffChange.next_change_id
      TENANCY = Common::DiffChange.next_change_id
      VOLUME_GROUPS = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class InstanceDiff < Common::Diff
      include InstanceChange

      def asset_type
        case @type
        when EBS then "EBS Optimized"
        when PROFILE then "Instance Profile"
        when MONITORING then "Monitoring"
        when INTERFACES then "Network Interfaces"
        when SDCHECK then "Source Dest Check"
        when SECURITY_GROUPS then "Security Groups"
        when SUBNET then "Subnet"
        when TYPE then "Type"
        when TENANCY then "Tenancy"
        when VOLUME_GROUPS then "Volume Groups"
        else
          "EC2 Instance"
        end
      end

      def aws_name
        @aws.name
      end

      def diff_string
        case @type
        when EBS, PROFILE, MONITORING, INTERFACES, SDCHECK, SUBNET, TYPE, TENANCY
          [
            "#{asset_type}:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when SECURITY_GROUPS
          [
            "#{asset_type}:",
            @changes.removed.map { |sg| Colors.unmanaged("\t#{sg}") },
            @changes.added.map { |sg| Colors.added("\t#{sg}") }
          ].flatten.join("\n")
        when VOLUME_GROUPS
          [
            "#{asset_type}:",
            @changes.removed.map { |vg, _| Colors.unmanaged("\t#{vg} is attached but not managed by Cumulus") },
            @changes.added.map { |vg, _| Colors.added("\t#{vg} will be attached to the instance") },
            @changes.modified.map do |vg, diff|
              [
                "\t#{vg}:",
                diff.changes.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ]
            end
          ].flatten.join("\n")
        end
      end
    end
  end
end
