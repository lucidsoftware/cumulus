require "aws-sdk"

module Cumulus
  module Kinesis
    class << self

      @@client = Aws::Kinesis::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)

      require "aws_extensions/kinesis/StreamDescription"
      Aws::Kinesis::Types::StreamDescription.send(:include, AwsExtensions::Kinesis::StreamDescription)

      # Public - Returns a Hash of stream name to Aws::Kinesis::Types::StreamDescription with all shards loaded
      def named_streams
        @named_streams ||= Hash[stream_names.map { |name| [name, describe_stream(name)] }]
      end

      # Public - Returns an array of all the stream names
      def stream_names
        @stream_names ||= init_stream_names
      end

      # Public - Returns a Hash of stream name to tags
      def stream_tags
        @stream_tags ||= Hash[stream_names.map { |name| [name, init_tags(name) ] }]
      end

      # Public - Load the entire stream description with all shards
      #
      # Returns a Aws::Kinesis::Types::StreamDescription with all shards loaded
      def describe_stream(stream_name)
        stream = @@client.describe_stream({
          stream_name: stream_name
        }).stream_description

        while stream.has_more_shards do
          stream_continued = @@client.describe_stream({
            stream_name: stream_name,
            exclusive_start_shard_id: stream.shards.last.shard_id
          }).stream_description

          stream.shards.concat(stream_continued.shards)
          stream.has_more_shards = stream_continued.has_more_shards
        end

        stream
      end

      private

      # Internal - Load the tags for a stream
      #
      # Returns a Hash containing the tags as key/value pairs
      def init_tags(stream_name)
        response = @@client.list_tags_for_stream({
          stream_name: stream_name,
        })

        tags = response.tags

        while response.has_more_tags do
          response = @@client.list_tags_for_stream({
            stream_name: stream_name,
            exclusive_start_tag_key: tags.last.key
          })

          tags.concat(response.tags)
        end

        Hash[tags.map { |tag| [tag.key, tag.value] }]
      end

      # Internal - Load the list of stream names
      #
      # Returns the stream names as an Array
      def init_stream_names
        streams = []

        has_more_streams = true

        while has_more_streams do
          response = @@client.list_streams({
            exclusive_start_stream_name: streams.last
          })

          streams.concat(response.stream_names)
          has_more_streams = response.has_more_streams
        end

        streams
      end

    end
  end
end