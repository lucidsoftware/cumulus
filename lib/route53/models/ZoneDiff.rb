require "conf/Configuration"
require "common/models/Diff"
require "route53/models/RecordDiff"
require "util/Colors"

module Cumulus
  module Route53
    # Public: The types of changes that can be made to zones
    module ZoneChange
      include Common::DiffChange

      COMMENT = Common::DiffChange::next_change_id
      DOMAIN = Common::DiffChange::next_change_id
      PRIVATE = Common::DiffChange::next_change_id
      RECORD = Common::DiffChange::next_change_id
      VPC = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of zones.
    class ZoneDiff < Common::Diff
      include ZoneChange

      attr_accessor :changed_records

      # Public: Static method that produces a diff representing changes in records
      #
      # changed_records - the RecordDiffs
      # local           - the local configuration for the zone
      #
      # Returns the diff
      def self.records(changed_records, local)
        diff = ZoneDiff.new(RECORD, nil, local)
        diff.changed_records = changed_records
        diff
      end

      def asset_type
        "Zone"
      end

      def aws_name
        access = if @aws.config.private_zone then "private" else "public" end
        "#{@aws.name} (#{access})"
      end

      def add_string
        "has been added locally, but must be created in AWS manually."
      end

      def diff_string
        case @type
        when COMMENT
          [
            "Comment:",
            Colors.aws_changes("\tAWS - #{@aws.config.comment}"),
            Colors.local_changes("\tLocal - #{@local.comment}")
          ].join("\n")
        when DOMAIN
          [
            "Domain: AWS - #{Colors.aws_changes(@aws.name)}, Local - #{Colors.local_changes(@local.domain)}",
            "\tAWS doesn't allow you to change the domain for a zone."
          ].join("\n")
        when PRIVATE
          [
            "Private: AWS - #{Colors.aws_changes(@aws.config.private_zone)}, Local - #{Colors.local_changes(@local.private)}",
            "\tAWS doesn't allow you to change whether a zone is private."
          ].join("\n")
        when RECORD
          if Configuration.instance.route53.print_all_ignored
            [
              "Records:",
              @changed_records.map { |r| "\t#{r}" }
            ].flatten.join("\n")
          else
            [
              "Records:",
              @changed_records.reject { |r| r.type == RecordChange::IGNORED }.map { |r| "\t#{r}" },
              "\tYour blacklist ignored #{@changed_records.select { |r| r.type == RecordChange::IGNORED }.size} records."
            ].flatten.join("\n")
          end
        when VPC
          [
            "VPCs:",
            added_vpc_ids.map { |vpc| Colors.added("\t#{vpc["id"]} | #{vpc["region"]}") },
            removed_vpc_ids.map { |vpc| Colors.removed("\t#{vpc["id"]} | #{vpc["region"]}") }
          ].flatten.join("\n")
        end
      end

      # Public: Get the VPCs that have been added locally.
      #
      # Returns an array of vpc ids
      def added_vpc_ids
        @local.vpc - @aws.vpc
      end

      # Public: Get the VPCs that have been removed locally.
      #
      # Returns an array of vpc ids
      def removed_vpc_ids
        @aws.vpc - @local.vpc
      end

    end
  end
end
