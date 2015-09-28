require "common/models/Diff"
require "common/models/ListChange"
require "common/models/TagsDiff"
require "vpc/models/AclEntryDiff"
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

      def self.entries(type, aws, local)
        aws_rule_entries = Hash[aws.map do |entry|
          aws_entry = AclEntryConfig.new
          aws_entry.populate!(entry)
          [entry.rule_number, aws_entry]
        end]
        local_rule_entries = Hash[local.map { |entry| [entry.rule, entry] }]

        added_diffs = Hash[local_rule_entries.reject { |rule, entry| aws_rule_entries.has_key? rule }.map do |rule, local_entry|
          [rule, AclEntryDiff.added(local_entry)]
        end]
        removed_diffs = Hash[aws_rule_entries.reject { |rule, entry| local_rule_entries.has_key? rule }.map do |rule, aws_entry|
          [rule, AclEntryDiff.unmanaged(aws_entry)]
        end]

        modified_diffs = Hash[local_rule_entries.select { |rule, entry| aws_rule_entries.has_key? rule }.map do |rule, local_entry|
          aws_entry = aws_rule_entries[rule]
          entry_diffs = local_entry.diff(aws_entry)
          if !entry_diffs.empty?
            [rule, AclEntryDiff.modified(aws_entry, local_entry, entry_diffs)]
          end
        end.reject { |v| v.nil? }]

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = NetworkAclDiff.new(type, aws, local)
          diff.changes = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
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
            @changes.removed.map do |rule, removed_diff|
              Colors.unmanaged(removed_diff.aws.pretty_string.lines.map { |l| "\t\t#{l}".chomp("\n") }.join("\n"))
            end.flatten.join("\n\t\t\t---\n")
          ].reject { @changes.removed.empty? },
          [
            "\tThese rules will be created:",
            @changes.added.map do |rule, added_diff|
              Colors.added(added_diff.local.pretty_string.lines.map { |l| "\t\t#{l}".chomp("\n") }.join("\n"))
            end.flatten.join("\n\t\t\t---\n")
          ].reject { @changes.added.empty? },
          @changes.modified.map do |rule, modified_diff|
            [
              "\tRule #{rule} was modified:",
              modified_diff.changes.map do |diff|
                diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
              end
            ]
          end
        ].flatten.join("\n")
      end
    end
  end
end
