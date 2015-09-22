require "common/models/Diff"
require "common/models/ListChange"
require "common/models/TagsDiff"
require "util/Colors"

require "json"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to the network acl
    module NetworkAclChange
      include Common::DiffChange

      INBOUND = Common::DiffChange.next_change_id
      OUTBOUND = Common::DiffChange.next_change_id
      TAGS = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS configuration
    class NetworkAclDiff < Common::Diff
      include NetworkAclChange
      include Common::TagsDiff

      attr_accessor :entries

      def self.entries(type, aws, local)
        aws_rule_entries = Hash[aws.map do |entry|
          [entry.rule_number, entry]
        end]
        local_rule_entries = Hash[local.map { |entry| [entry.rule, entry] }]

        added = local_rule_entries.reject { |k, v| aws_rule_entries.has_key? k }
        removed = Hash[aws_rule_entries.reject { |k, v| local_rule_entries.has_key? k }.map do |rule, aws|
          aws_entry = AclEntryConfig.new
          aws_entry.populate!(aws_rule_entries[rule])
          [rule, aws_entry]
        end]
        modified = local_rule_entries.select { |k, v| aws_rule_entries.has_key? k }

        modified_diffs = Hash[modified.map do |rule, entry|
          aws_entry = AclEntryConfig.new
          aws_entry.populate!(aws_rule_entries[rule])
          [rule, entry.diff(aws_entry)]
        end].reject { |k, v| v.empty? }

        if !added.empty? or !removed.empty? or !modified_diffs.empty?
          diff = NetworkAclDiff.new(type, aws, local)
          diff.entries = Common::ListChange.new(added, removed, modified_diffs)
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
        "Network Acl"
      end

      def aws_name
        @aws.name || @aws.network_acl_id
      end

      def diff_string
        case @type
        when INBOUND
          [
            "Inbound Rules:",
            entries_diff_string
          ].flatten.join("\n")
        when OUTBOUND
          [
            "Outbound Rules:",
            entries_diff_string
          ].flatten.join("\n")
        when TAGS
          tags_diff_string
        end
      end

      private

      def entries_diff_string
        [
          [
            "\tThese rules will be deleted:",
            @entries.removed.map do |rule, entry|
              Colors.unmanaged(entry.pretty_string.lines.map { |l| "\t\t#{l}".chomp("\n") }.join("\n"))
            end.flatten.join("\n\t\t\t---\n")
          ].reject { @entries.removed.empty? },
          [
            "\tThese rules will be created:",
            @entries.added.map do |rule, entry|
              Colors.added(entry.pretty_string.lines.map { |l| "\t\t#{l}".chomp("\n") }.join("\n"))
            end.flatten.join("\n\t\t\t---\n")
          ].reject { @entries.added.empty? },
          @entries.modified.map do |rule, diffs|
            [
              "\tRule #{rule} was modified:",
              diffs.map do |diff|
                diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
              end
            ]
          end
        ].flatten.join("\n")
      end
    end
  end
end
