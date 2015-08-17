require "common/models/Diff"
require "elb/ELB"
require "util/Colors"

module Cumulus
  module Route53
    # Public: The types of changes that can be made to records
    module RecordChange
      include Common::DiffChange

      ALIAS = Common::DiffChange::next_change_id
      CHANGED = Common::DiffChange::next_change_id
      IGNORED = Common::DiffChange::next_change_id
      TTL = Common::DiffChange::next_change_id
      VALUE = Common::DiffChange::next_change_id
    end

    # Public: Represents differences between local configuration and AWS
    # configuration for records.
    class RecordDiff < Common::Diff
      include RecordChange

      attr_accessor :message
      attr_accessor :changes

      # Public: Static method that will create a diff that contains a message but is
      # ignored when syncing.
      #
      # message - the message to display
      # aws   - the aws configuration for the record
      #
      # Returns the diff
      def self.ignored(message, aws)
        diff = RecordDiff.new(IGNORED, aws)
        diff.message = message
        diff
      end

      # Public: Static method that will create a diff that contains a bunch of
      # singular changes.
      #
      # changes - the changes for the record
      # local   - the local configuration for the record
      #
      # Returns the diff
      def self.changed(changes, local)
        diff = RecordDiff.new(CHANGED, nil, local)
        diff.changes = changes
        diff
      end

      def asset_type
        "Record"
      end

      def aws_name
        "(#{@aws.type}) #{@aws.name}"
      end

      def local_name
        @local.readable_name
      end

      def diff_string
        case @type
        when IGNORED
          message
        when CHANGED
          [
            "Record #{local_name}:",
            changes.map { |c| "\t\t#{c}" }
          ].flatten.join("\n")
        end
      end

    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration for a single record. This class allows all the changes for a
    # record to be grouped together when printed.
    class SingleRecordDiff < Common::Diff
      include RecordChange

      def diff_string
        case @type
        when ALIAS
          if @local.is_elb_alias?
            aws_name = ELB::get_aws_by_dns_name(@aws.alias_target.elb_dns_name).load_balancer_name
            "Alias: AWS - #{Colors.aws_changes(aws_name)}, Local - #{Colors.local_changes(@local.alias_target.name)}"
          else
            "Alias: AWS - #{Colors.aws_changes(@aws.alias_target.chomped_dns)}, Local - #{Colors.local_changes(@local.alias_target.dns_name)}"
          end
        when TTL
          "TTL: AWS - #{Colors.aws_changes(@aws.ttl)}, Local - #{Colors.local_changes(@local.ttl)}"
        when VALUE
          [
            "Value:",
            values_to_add.map { |v| Colors.added("\t\t\t#{v}") },
            values_to_remove.map { |v| Colors.removed("\t\t\t#{v}") }
          ].flatten.join("\n")
        end
      end

      private

      # Internal: Get the value parts that are in local configuration but not in AWS
      #
      # Returns the local value parts
      def values_to_add
        aws_value = @aws.resource_records.map(&:value)
        @local.value.reject { |v| aws_value.include?(v) }
      end

      # Internal: Get the value parts that are in AWS but not local configuration
      #
      # Returns the AWS value parts
      def values_to_remove
        aws_value = @aws.resource_records.map(&:value)
        aws_value.reject { |v| @local.value.include?(v) }
      end
    end
  end
end
