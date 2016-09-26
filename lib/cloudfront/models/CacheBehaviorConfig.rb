require "conf/Configuration"
require "cloudfront/models/CacheBehaviorDiff"
require "util/AwsUtil"

require "json"

module Cumulus
  module CloudFront
    # Public: An object representing configuration for a distribution cache behavior
    class CacheBehaviorConfig
      attr_reader :default
      attr_reader :path_pattern
      attr_reader :target_origin_id
      attr_reader :forward_query_strings
      attr_reader :forwarded_cookies
      attr_reader :forwarded_cookies_whitelist
      attr_reader :forward_headers
      attr_reader :allow_blank_referer
      attr_reader :referer_checks
      attr_reader :referer_whitelist
      attr_reader :trusted_signers
      attr_reader :viewer_protocol_policy
      attr_reader :min_ttl
      attr_reader :max_ttl
      attr_reader :default_ttl
      attr_reader :smooth_streaming
      attr_reader :allowed_methods
      attr_reader :cached_methods
      attr_reader :compress

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the distribution cache behavior
      # default - indicates if the cache configuration is the default config (ignore path_pattern if so)
      def initialize(json = nil, default = false)
        if !json.nil?
          @default = default
          @path_pattern = json["path-pattern"] if !default
          @target_origin_id = json["target-origin-id"]
          @forward_query_strings = json["forward-query-strings"]
          @forward_query_string_cache_keys = json["forward-query-strings-cache-keys"] || []
          @forwarded_cookies = json["forwarded-cookies"]
          @forwarded_cookies_whitelist = json["forwarded-cookies-whitelist"] || []
          @forward_headers = json["forward-headers"] || []
          @trusted_signers = json["trusted-signers"] || []
          @viewer_protocol_policy = json["viewer-protocol-policy"]
          @min_ttl = json["min-ttl"]
          @max_ttl = json["max-ttl"]
          @default_ttl = json["default-ttl"]
          @smooth_streaming = json["smooth-streaming"]
          @allowed_methods = json["allowed-methods"] || []
          @cached_methods = json["cached-methods"] || []
          @compress = json["compress"] || false
        end
      end

      def populate!(aws, default = false)
        @default = default
        @path_pattern = aws.path_pattern if !default
        @target_origin_id = aws.target_origin_id
        @forward_query_strings = aws.forwarded_values.query_string
        @forward_query_string_cache_keys =  aws.forwarded_valued.query_string_cache_keys.items || []
        @forwarded_cookies = aws.forwarded_values.cookies.forward
        @forwarded_cookies_whitelist = if aws.forwarded_values.cookies.whitelisted_names.nil? then [] else aws.forwarded_values.cookies.whitelisted_names.items end
        @forward_headers = if aws.forwarded_values.headers.nil? then [] else aws.forwarded_values.headers.items end
        @trusted_signers = if aws.trusted_signers.enabled then aws.trusted_signers.items else [] end
        @viewer_protocol_policy = aws.viewer_protocol_policy
        @min_ttl = aws.min_ttl
        @max_ttl = aws.max_ttl
        @default_ttl = aws.default_ttl
        @smooth_streaming = aws.smooth_streaming
        @allowed_methods = aws.allowed_methods.items
        @cached_methods = aws.allowed_methods.cached_methods.items
        @compress = aws.compress
      end

      # Public: Get the config as a hash
      #
      # Returns the hash
      def to_local
        {
          "path-pattern" => @path_pattern,
          "target-origin-id" => @target_origin_id,
          "forward-query-strings" => @forward_query_strings,
          "forward-query-string-cache-keys" => @forward_query_string_cache_keys,
          "forwarded-cookies" => @forwarded_cookies,
          "forwarded-cookies-whitelist" => @forwarded_cookies_whitelist,
          "forward-headers" => @forward_headers,
          "trusted-signers" => @trusted_signers,
          "viewer-protocol-policy" => @viewer_protocol_policy,
          "min-ttl" => @min_ttl,
          "max-ttl" => @max_ttl,
          "default-ttl" => @default_ttl,
          "smooth-streaming" => @smooth_streaming,
          "allowed-methods" => @allowed_methods,
          "cached-methods" => @cached_methods,
          "compress" => @compress
        }.reject { |k, v| v.nil? }
      end

      # Public: Get the config in the format needed for AWS
      #
      # Returns the hash
      def to_aws
        {
          path_pattern: @path_pattern,
          target_origin_id: @target_origin_id,
          forwarded_values: {
            query_string: @forward_query_strings,
            query_string_cache_keys: AwsUtil.aws_array(@forward_query_string_cache_keys),
            cookies: {
              forward: @forwarded_cookies,
              whitelisted_names: AwsUtil.aws_array(@forwarded_cookies_whitelist),
            },
            headers: AwsUtil.aws_array(@forward_headers)
          },
          trusted_signers: {
            enabled: !@trusted_signers.empty?,
            quantity: @trusted_signers.size,
            items: AwsUtil.array_or_nil(@trusted_signers)
          },
          viewer_protocol_policy: @viewer_protocol_policy,
          min_ttl: @min_ttl,
          max_ttl: @max_ttl,
          default_ttl: @default_ttl,
          smooth_streaming: @smooth_streaming,
          allowed_methods: {
            quantity: @allowed_methods.size,
            items: AwsUtil.array_or_nil(@allowed_methods),
            cached_methods: AwsUtil.aws_array(@cached_methods)
          },
          compress: @compress
        }
      end

      def name
        if @default
          "Default Cache"
        else
          "#{target_origin_id}/#{path_pattern}"
        end
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the CacheBehaviorDiffs that were found
      def diff(aws)
        diffs = []

        if !default and @path_pattern != aws.path_pattern
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::PATH, aws, self)
        end

        if @target_origin_id != aws.target_origin_id
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::TARGET, aws, self)
        end

        if @forward_query_strings != aws.forwarded_values.query_string
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::QUERY, aws, self)
        end

        if @forwarded_cookies != aws.forwarded_values.cookies.forward
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::COOKIES, aws, self)
        end

        aws_whitelist_cookies = if aws.forwarded_values.cookies.whitelisted_names.nil? then [] else aws.forwarded_values.cookies.whitelisted_names.items end
        added_cookies = (@forwarded_cookies_whitelist - aws_whitelist_cookies)
        removed_cookies = (aws_whitelist_cookies - @forwarded_cookies_whitelist)
        if !added_cookies.empty? or !removed_cookies.empty?
          diffs << CacheBehaviorDiff.cookies_whitelist(added_cookies, removed_cookies, self)
        end

        aws_query_string_cache_keys = aws.forwarded_values.query_string_cache_keys.items || []
        added_keys = (@forward_query_string_cache_keys - aws_query_string_cache_keys)
        removed_keys = (aws_query_string_cache_keys - @forward_query_string_cache_keys)
        if !(added_keys.empty? && removed_keys.empty?)
          diffs << CacheBehaviorDiff.query_string_cache_keys(added_keys, removed_keys, self)
        end

        aws_headers = if aws.forwarded_values.headers.nil? then [] else aws.forwarded_values.headers.items end
        added_headers = (@forward_headers - aws_headers)
        removed_headers = (aws_headers - @forward_headers)
        if !added_headers.empty? or !removed_headers.empty?
          diffs << CacheBehaviorDiff.headers(added_headers, removed_headers, self)
        end

        aws_signers = if !aws.trusted_signers.enabled then [] else aws.trusted_signers.items end
        added_signers = (@trusted_signers - aws_signers)
        removed_signers = (aws_signers - @trusted_signers)
        if !added_signers.empty? or !removed_signers.empty?
          diffs << CacheBehaviorDiff.signers(added_signers, removed_signers, self)
        end

        if @viewer_protocol_policy != aws.viewer_protocol_policy
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::VIEWER_PROTOCOL, aws, self)
        end

        if @min_ttl != aws.min_ttl
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::MINTTL, aws, self)
        end

        if @max_ttl != aws.max_ttl
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::MAXTTL, aws, self)
        end

        if @default_ttl != aws.default_ttl
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::DEFTTL, aws, self)
        end

        if @smooth_streaming != aws.smooth_streaming
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::STREAMING, aws, self)
        end

        aws_allowed_methods = if aws.allowed_methods.nil? then [] else aws.allowed_methods.items end
        added_allowed_methods = (@allowed_methods - aws_allowed_methods)
        removed_allowed_methods = (aws_allowed_methods - @allowed_methods)
        if !added_allowed_methods.empty? or !removed_allowed_methods.empty?
          diffs << CacheBehaviorDiff.allowed_methods(added_allowed_methods, removed_allowed_methods, self)
        end

        aws_cached_methods = if aws.allowed_methods.nil? or aws.allowed_methods.cached_methods.nil? then [] else aws.allowed_methods.cached_methods.items end
        added_cached_methods = (@cached_methods - aws_cached_methods)
        removed_cached_methods = (aws_cached_methods - @cached_methods)
        if !added_cached_methods.empty? or !removed_cached_methods.empty?
          diffs << CacheBehaviorDiff.cached_methods(added_cached_methods, removed_cached_methods, self)
        end

        if @compress != aws.compress
          diffs << CacheBehaviorDiff.new(CacheBehaviorChange::COMPRESS, aws, self)
        end

        diffs
      end

    end
  end
end
