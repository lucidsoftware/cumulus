require "conf/Configuration"
require "cloudfront/models/DistributionDiff"
require "cloudfront/models/OriginConfig"
require "cloudfront/models/CacheBehaviorConfig"

require "json"

module Cumulus
  module CloudFront
    # Public: An object representing configuration for a distribution
    class DistributionConfig
      attr_accessor :id
      attr_reader :file_name
      attr_reader :name
      attr_reader :aliases
      attr_reader :origins
      attr_reader :default_cache_behavior
      attr_reader :cache_behaviors
      attr_reader :comment
      attr_reader :enabled

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the distribution
      def initialize(name, json = nil)
        @file_name = name
        if !json.nil?
          @id = json["id"]
          @name = if @id.nil? then @file_name else @id end
          @aliases = json["aliases"] || []
          @origins = json["origins"].map { |o| OriginConfig.new(o) }
          @default_cache_behavior = CacheBehaviorConfig.new(json["default-cache-behavior"], true)
          @cache_behaviors = if json["cache-behaviors"].nil? then [] else json["cache-behaviors"].map { |cb| CacheBehaviorConfig.new(cb) } end
          @comment = json["comment"]
          @enabled = json["enabled"]
        end
      end

      # Public: Get the config as a prettified JSON string.
      #
      # Returns the JSON string
      def pretty_json
        JSON.pretty_generate({
          "id" => @id,
          "aliases" => @aliases,
          "origins" => @origins.map(&:to_hash),
          "default-cache-behavior" => @default_cache_behavior.to_hash,
          "cache-behaviors" => @cache_behaviors.map(&:to_hash),
          "comment" => @comment,
          "enabled" => @enabled,
        }.reject { |k, v| v.nil? })
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the DistributionDiffs that were found
      def diff(aws)
        diffs = []

        added_aliases = (@aliases - aws.aliases.items)
        removed_aliases = aws.aliases.items - @aliases
        if !added_aliases.empty? or !removed_aliases.empty?
          diffs << DistributionDiff.aliases(added_aliases, removed_aliases, self)
        end

        origin_diffs = diff_origins(aws.origins.items)
        if !origin_diffs.empty?
          diffs << DistributionDiff.origins(origin_diffs, self)
        end

        default_cache_diffs = @default_cache_behavior.diff(aws.default_cache_behavior)
        if !default_cache_diffs.empty?
          diffs << DistributionDiff.default_cache(default_cache_diffs, self)
        end

        diffs << diff_caches(aws)

        if @comment != aws.comment
          diffs << DistributionDiff.new(DistributionChange::COMMENT, aws, self)
        end

        if @enabled != aws.enabled
          diffs << DistributionDiff.new(DistributionChange::ENABLED, aws, self)
        end

        diffs.flatten
      end

      private

      # Internal: Produce an array of differences between the local origins and the aws origins
      #
      # aws_origins - the AWS origins from a cloudfront config
      #
      # Returns an array of OriginDiffs that were found
      def diff_origins(aws_origins)
        diffs = []

        # map the origins to their keys
        aws = Hash[aws_origins.map { |o| [o.id, o] }]
        local = Hash[@origins.map { |o| [o.id, o] }]

        # find origins that are not configured locally
        aws.each do |origin_id, origin|
          if !local.include?(origin_id)
            diffs << OriginDiff.unmanaged(origin)
          end
        end

        local.each do |origin_id, origin|
          if !aws.include?(origin_id)
            diffs << OriginDiff.added(origin)
          else
            diffs << origin.diff(aws[origin_id])
          end
        end

        diffs.flatten
      end

      # Internal: Produce an array of differences between local cache behaviors and aws cache behaviors
      #
      # aws - the AWS config
      #
      # Returns an array of CacheBehaviorDiff
      def diff_caches(aws)
        removed = []
        added = []
        changed = Hash.new

        aws_cache_behaviors = if aws.cache_behaviors.nil? then [] else aws.cache_behaviors.items end

        aws = Hash[aws_cache_behaviors.map { |c| ["#{c.target_origin_id}/#{c.path_pattern}", c]}]
        local = Hash[@cache_behaviors.map { |c| ["#{c.target_origin_id}/#{c.path_pattern}", c]}]

        # find cache behaviors that are not configured locally
        aws.each do |cache_id, cache|
          if !local.include?(cache_id)
            removed << CacheBehaviorDiff.unmanaged(cache)
          end
        end

        local.each do |cache_id, cache|
          if !aws.include?(cache_id)
            added << CacheBehaviorDiff.added(cache)
          else
            diffs = cache.diff(aws[cache_id])
            changed[cache_id] = diffs if !diffs.empty?
          end
        end

        if !removed.empty? or !added.empty? or !changed.empty?
          DistributionDiff.caches(removed, added, changed, self)
        else
          []
        end

      end

    end
  end
end
