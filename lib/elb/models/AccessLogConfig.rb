require "elb/models/AccessLogDiff"

module Cumulus
  module ELB
    # Public: An object representing configuration for a load balancer
    class AccessLogConfig
      attr_reader :enabled
      attr_reader :s3_bucket
      attr_reader :emit_interval
      attr_reader :bucket_prefix

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the load balancer
      def initialize(json = nil)
        @enabled = !json.nil?
        if !json.nil?
          @s3_bucket = json["s3-bucket"]
          @emit_interval = json["emit-interval"]
          @bucket_prefix = json["bucket-prefix"]
        end
      end

      def to_hash
        if @enabled
          {
            "s3-bucket" => @s3_bucket,
            "emit-interval" => @emit_interval,
            "bucket-prefix" => @bucket_prefix,
          }.reject { |k, v| v.nil? }
        else
          false
        end
      end

      def to_aws
        {
          enabled: @enabled,
          s3_bucket_name: @s3_bucket,
          emit_interval: @emit_interval,
          s3_bucket_prefix: @bucket_prefix,
        }.reject { |k, v| v.nil? }
      end

      def populate!(aws)
        @enabled = aws.enabled
        @s3_bucket = aws.s3_bucket_name
        @emit_interval = aws.emit_interval
        @bucket_prefix = aws.s3_bucket_prefix
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the HealthCheckDiffs that were found
      def diff(aws)
        diffs = []

        if @enabled != aws.enabled
          diffs << AccessLogDiff.new(AccessLogChange::ENABLED, aws.enabled, @enabled)
        end

        if @s3_bucket != aws.s3_bucket_name
          diffs << AccessLogDiff.new(AccessLogChange::BUCKET, aws.s3_bucket_name, @s3_bucket)
        end

        if @emit_interval != aws.emit_interval
          diffs << AccessLogDiff.new(AccessLogChange::EMIT, aws.emit_interval, @emit_interval)
        end

        if @bucket_prefix != aws.s3_bucket_prefix
          diffs << AccessLogDiff.new(AccessLogChange::PREFIX, aws.s3_bucket_prefix, @bucket_prefix)
        end

        diffs.flatten
      end

    end
  end
end
