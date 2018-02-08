require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

module Cumulus
  module CloudFront

    # Public: The types of changes that can be made to cache behaviors
    module CacheBehaviorChange
      include Common::DiffChange

      PATH = Common::DiffChange::next_change_id
      TARGET = Common::DiffChange::next_change_id
      QUERY = Common::DiffChange::next_change_id
      COOKIES = Common::DiffChange::next_change_id
      COOKIES_WHITELIST = Common::DiffChange::next_change_id
      QUERY_STRING_CACHE_KEYS = Common::DiffChange::next_change_id
      HEADERS = Common::DiffChange::next_change_id
      SIGNERS = Common::DiffChange::next_change_id
      VIEWER_PROTOCOL = Common::DiffChange::next_change_id
      MINTTL = Common::DiffChange::next_change_id
      MAXTTL = Common::DiffChange::next_change_id
      DEFTTL = Common::DiffChange::next_change_id
      STREAMING = Common::DiffChange::next_change_id
      METHODS_ALLOWED = Common::DiffChange::next_change_id
      METHODS_CACHED = Common::DiffChange::next_change_id
      COMPRESS = Common::DiffChange::next_change_id
      LAMBDA_FUNCTION_ASSOCIATIONS = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of zones.
    class CacheBehaviorDiff < Common::Diff
      include CacheBehaviorChange

      attr_accessor :cookies
      attr_accessor :query_string_cache_keys
      attr_accessor :headers
      attr_accessor :signers
      attr_accessor :allowed_methods
      attr_accessor :cached_methods
      attr_accessor :lambda_function_associations

      # Public: Static method that produces a diff representing changes in CacheBehavior cookies whitelist
      #
      # added_cookies   - the cookies that were added
      # removed_cookies - the cookies that were removed
      # local           - the local configuration for the zone
      #
      # Returns the diff
      def self.cookies_whitelist(added_cookies, removed_cookies, local)
        diff = CacheBehaviorDiff.new(COOKIES_WHITELIST, nil, local)
        diff.cookies = Common::ListChange.new(added_cookies, removed_cookies)
        diff
      end

      # Public: Static method that produces a diff representing changes in CacheBehavior query string
      # cache keys
      #
      # added_keys - the keys that were added
      # removed_keys - the keys that were removed
      # local - the local configuration for the zone
      #
      # Returns the diff
      def self.query_string_cache_keys(added_keys, removed_keys, local)
        diff = CacheBehaviorDiff.new(QUERY_STRING_CACHE_KEYS, nil, local)
        diff.query_string_cache_keys = Common::ListChange.new(added_keys, removed_keys)
        diff
      end

      # Public: Static method that produces a diff representing changes in CacheBehavior headers
      #
      # added_headers   - the headers that were added
      # removed_headers - the headers that were removed
      # local           - the local configuration for the zone
      #
      # Returns the diff
      def self.headers(added_headers, removed_headers, local)
        diff = CacheBehaviorDiff.new(HEADERS, nil, local)
        diff.headers = Common::ListChange.new(added_headers, removed_headers)
        diff
      end

      # Public: Static method that produces a diff representing changes in CacheBehavior trusted signers
      #
      # added_signers   - the trusted signers that were added
      # removed_signers - the trusted signers that were removed
      # local           - the local configuration for the zone
      #
      # Returns the diff
      def self.signers(added_signers, removed_signers, local)
        diff = CacheBehaviorDiff.new(SIGNERS, nil, local)
        diff.signers = Common::ListChange.new(added_signers, removed_signers)
        diff
      end

      # Public: Static method that produces a diff representing changes in CacheBehavior allowed methods
      #
      # added_allowed_methods   - the allowed methods that were added
      # removed_allowed_methods - the allowed methods that were removed
      # local                   - the local configuration for the zone
      #
      # Returns the diff
      def self.allowed_methods(added_allowed_methods, removed_allowed_methods, local)
        diff = CacheBehaviorDiff.new(METHODS_ALLOWED, nil, local)
        diff.allowed_methods = Common::ListChange.new(added_allowed_methods, removed_allowed_methods)
        diff
      end

      # Public: Static method that produces a diff representing changes in CacheBehavior cached methods
      #
      # added_cached_methods   - the cached methods that were added
      # removed_cached_methods - the cached methods that were removed
      # local                   - the local configuration for the zone
      #
      # Returns the diff
      def self.cached_methods(added_cached_methods, removed_cached_methods, local)
        diff = CacheBehaviorDiff.new(METHODS_CACHED, nil, local)
        diff.cached_methods = Common::ListChange.new(added_cached_methods, removed_cached_methods)
        diff
      end

      # Public: Static method that produces a diff representing changes in CacheBehavior lambda function associations
      #
      # added_assocs   - the cached methods that were added
      # removed_assocs - the cached methods that were removed
      # local          - the local configuration for the zone
      #
      # Returns the diff
      def self.lambda_function_associations(added_assocs, removed_assocs, local)
        diff = CacheBehaviorDiff.new(LAMBDA_FUNCTION_ASSOCIATIONS, nil, local)
        diff.lambda_function_associations = Common::ListChange.new(added_assocs, removed_assocs)
        diff
      end

      def diff_string
        case @type
        when PATH
          [
            "path:",
            Colors.aws_changes("\tAWS - #{@aws.path_pattern}"),
            Colors.local_changes("\tLocal - #{@local.path_pattern}"),
          ].join("\n")
        when TARGET
          [
            "target origin id:",
            Colors.aws_changes("\tAWS - #{@aws.target_origin_id}"),
            Colors.local_changes("\tLocal - #{@local.target_origin_id}"),
          ].join("\n")
        when QUERY
          [
            "forward query strings:",
            Colors.aws_changes("\tAWS - #{@aws.forwarded_values.query_string}"),
            Colors.local_changes("\tLocal - #{@local.forward_query_strings}"),
          ].join("\n")
        when COOKIES
          [
            "forwarded cookies:",
            Colors.aws_changes("\tAWS - #{@aws.forwarded_values.cookies.forward}"),
            Colors.local_changes("\tLocal - #{@local.forwarded_cookies}"),
          ].join("\n")
        when COOKIES_WHITELIST
          [
            "whitelisted forwarded cookies:",
            cookies.removed.map{ |removed| Colors.removed("\t#{removed}")},
            cookies.added.map{ |added| Colors.added("\t#{added}")},
          ].flatten.join("\n")
        when QUERY_STRING_CACHE_KEYS
          [
            "Query String Cache Keys:",
            query_string_cache_keys.removed.map{ |removed| Colors.removed("\t#{removed}") },
            query_string_cache_keys.added.map{ |added| Colors.added("\t#{added}")}
          ].flatten.join("\n")
        when HEADERS
          [
            "forwarded headers:",
            headers.removed.map{ |removed| Colors.removed("\t#{removed}")},
            headers.added.map{ |added| Colors.added("\t#{added}")},
          ].flatten.join("\n")
        when SIGNERS
          [
            "trusted signers:",
            signers.removed.map{ |removed| Colors.removed("\t#{removed}")},
            signers.added.map{ |added| Colors.added("\t#{added}")},
          ].flatten.join("\n")
        when VIEWER_PROTOCOL
          [
            "viewer protocol policy:",
            Colors.aws_changes("\tAWS - #{@aws.viewer_protocol_policy}"),
            Colors.local_changes("\tLocal - #{@local.viewer_protocol_policy}"),
          ].join("\n")
        when MINTTL
          [
            "min ttl:",
            Colors.aws_changes("\tAWS - #{@aws.min_ttl}"),
            Colors.local_changes("\tLocal - #{@local.min_ttl}"),
          ].join("\n")
        when MAXTTL
          [
            "max ttl:",
            Colors.aws_changes("\tAWS - #{@aws.max_ttl}"),
            Colors.local_changes("\tLocal - #{@local.max_ttl}"),
          ].join("\n")
        when DEFTTL
          [
            "default ttl:",
            Colors.aws_changes("\tAWS - #{@aws.default_ttl}"),
            Colors.local_changes("\tLocal - #{@local.default_ttl}"),
          ].join("\n")
        when STREAMING
          [
            "smooth streaming:",
            Colors.aws_changes("\tAWS - #{@aws.smooth_streaming}"),
            Colors.local_changes("\tLocal - #{@local.smooth_streaming}"),
          ].join("\n")
        when METHODS_ALLOWED
          [
            "allowed methods:",
            allowed_methods.removed.map{ |removed| Colors.removed("\t#{removed}")},
            allowed_methods.added.map{ |added| Colors.added("\t#{added}")},
          ].flatten.join("\n")
        when METHODS_CACHED
          [
            "cached methods:",
            cached_methods.removed.map{ |removed| Colors.removed("\t#{removed}")},
            cached_methods.added.map{ |added| Colors.added("\t#{added}")},
          ].flatten.join("\n")
        when COMPRESS
          [
            "compress:",
            Colors.aws_changes("\tAWS - #{@aws.compress}"),
            Colors.local_changes("\tLocal - #{@local.compress}"),
          ].join("\n")
        when LAMBDA_FUNCTION_ASSOCIATIONS
          [
            "lambda_function_associations",
            lambda_function_associations.removed.map { |removed| Colors.removed("\t#{removed}")},
            lambda_function_associations.added.map { |added| Colors.added("\t#{added}") }
          ].join("\n")
        end
      end

      def asset_type
        "Cache Behavior"
      end

      def aws_name
        "#{@aws.target_origin_id}/#{@aws.path_pattern}"
      end

    end

  end
end
