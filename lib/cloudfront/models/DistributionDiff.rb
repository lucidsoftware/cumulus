require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

module Cumulus
  module CloudFront

  	# Public: The types of changes that can be made to zones
    module DistributionChange
      include Common::DiffChange

      ALIASES = Common::DiffChange::next_change_id
      ORIGINS = Common::DiffChange::next_change_id
      CACHE_DEFAULT = Common::DiffChange::next_change_id
      CACHES = Common::DiffChange::next_change_id
      COMMENT = Common::DiffChange::next_change_id
      ENABLED = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of zones.
    class DistributionDiff < Common::Diff
      include DistributionChange

      attr_accessor :changed_origins
      attr_accessor :added_aliases
      attr_accessor :removed_aliases
      attr_accessor :default_cache
      attr_accessor :cache

      # Public: Static method that produces a diff representing changes in origins
      #
      # changes - the OriginDiffs
      # local   - the local configuration for the distribution
      #
      # Returns the diff
      def self.origins(changes, local)
        diff = DistributionDiff.new(ORIGINS, nil, local)
        diff.changed_origins = changes
        diff
      end

      def self.aliases(added, removed, local)
        diff = DistributionDiff.new(ALIASES, nil, local)
        diff.added_aliases = added
        diff.removed_aliases = removed
        diff
      end

      def self.default_cache(diffs, local)
        diff = DistributionDiff.new(CACHE_DEFAULT, nil, local)
        diff.default_cache = diffs
        diff
      end

      def self.caches(removed, added, diffs, local)
        diff = DistributionDiff.new(CACHES, nil, local)
        diff.cache = Common::ListChange.new(removed, added, diffs)
        diff
      end

      def diff_string
        case @type
        when ALIASES
          [
            "aliases:",
            @removed_aliases.map { |removed| Colors.removed("\t#{removed}") },
            @added_aliases.map { |added| Colors.added("\t#{added}") },
          ].flatten.join("\n")
        when ORIGINS
          [
            "origins:",
            @changed_origins.map do |o|
              if o.type == ADD or o.type == UNMANAGED
                o.to_s.lines.map { |l| "\t#{l}".chomp("\n")}
              else
                [
                  "\t#{o.local_name}",
                  o.to_s.lines.map { |l| "\t\t#{l}".chomp("\n")}
                ].join("\n")
              end
            end
          ].flatten.join("\n")
        when CACHE_DEFAULT
          [
            "default cache behavior:",
            (@default_cache.map do |c|
              c.to_s.lines.map { |l| "\t#{l}".chomp("\n")}
            end).join("\n"),
          ].join("\n")
        when CACHES
          [
            "cache behaviors:",
            @cache.removed.map { |removed| Colors.removed("\t#{removed}") },
            @cache.added.map { |added| Colors.added("\t#{added}") },
            @cache.modified.map do |cache_name, cdiffs|
              [
                "\t#{cache_name}",
                cdiffs.map do |cdiff|
                  cdiff.to_s.lines.map { |l| "\t\t#{l.chomp}"}
                end
              ]
            end
          ].flatten.join("\n")
        when COMMENT
          [
            "comment:",
            Colors.aws_changes("\tAWS - #{@aws.comment}"),
            Colors.local_changes("\tLocal - #{@local.comment}"),
          ].join("\n")
        when ENABLED
          [
            "enabled:",
            Colors.aws_changes("\tAWS - #{@aws.enabled}"),
            Colors.local_changes("\tLocal - #{@local.enabled}"),
          ].join("\n")
        end
      end

      def asset_type
        "Cloudfront Distribution"
      end

      def aws_name
        @aws.id
      end

      def local_name
        @local.file_name
      end

    end

  end
end
