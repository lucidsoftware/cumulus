require "conf/Configuration"
require "kinesis/loader/Loader"
require "kinesis/models/StreamDiff"

require "json"

module Cumulus
  module Kinesis

    # Public: An object representing configuration for a Kiensis stream
    class StreamConfig
      attr_reader :name
      attr_reader :retention_period
      attr_reader :shards
      attr_reader :tags

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the stream
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @shards = json["shards"]
          @retention_period = json["retention-period"] || 24
          @tags = json["tags"] || {}
        end
      end

      def to_hash
        {
          "retention-period" => @retention_period,
          "shards" => @shards,
          "tags" => @tags
        }
      end

      # Public: Populate a config object with AWS configuration
      #
      # aws - the AWS configuration for the strean
      def populate!(aws)
        @retention_period = aws.retention_period_hours
        @shards = aws.sorted_shards.length
        @tags = Kinesis::stream_tags[aws.stream_name] || {}

        self
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the StreamDiffs that were found
      def diff(aws)
        diffs = []

        if @retention_period != aws.retention_period_hours
          diffs << StreamDiff.new(StreamChange::RETENTION, aws.retention_period_hours, @retention_period)
        end

        if @shards != aws.sorted_shards.length
          diffs << StreamDiff.new(StreamChange::SHARDS, aws.sorted_shards.length, @shards)
        end

        aws_tags = Kinesis::stream_tags[aws.stream_name]
        if @tags != aws_tags
          diffs << StreamDiff.new(StreamChange::TAGS, aws_tags, @tags)
        end

        diffs
      end

    end
  end
end
