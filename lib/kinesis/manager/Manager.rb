require "common/manager/Manager"
require "conf/Configuration"
require "kinesis/Kinesis"
require "kinesis/loader/Loader"
require "kinesis/models/StreamConfig"
require "kinesis/models/StreamDiff"

require "aws-sdk-kinesis"

module Cumulus
  module Kinesis
    class Manager < Common::Manager

      def initialize
        super()
        @create_asset = true
        @client = Aws::Kinesis::Client.new(Configuration.instance.client)
      end

      def resource_name
        "Kinesis Stream"
      end

      def local_resources
        @local_resources ||= Hash[Loader.streams.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= Kinesis::named_streams
      end

      def unmanaged_diff(aws)
        StreamDiff.unmanaged(aws)
      end

      def added_diff(local)
        StreamDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      def migrate
        puts Colors.blue("Migrating Kinesis Streams...")

        # Create the directories
        streams_dir = "#{@migration_root}/kinesis"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(streams_dir)
          Dir.mkdir(streams_dir)
        end

        Kinesis::named_streams.each do |name, stream|
          puts "Migrating stream #{name}"

          cumulus_stream = StreamConfig.new(name).populate!(stream)
          json = JSON.pretty_generate(cumulus_stream.to_hash)
          File.open("#{streams_dir}/#{name}.json", "w") { |f| f.write(json) }
        end

      end

      def create(local)
        @client.create_stream({
          stream_name: local.name,
          shard_count: local.shards
        })

        @client.wait_until(:stream_exists, {
          stream_name: local.name
        })

        # Describe the newly created stream
        created_stream = Kinesis::describe_stream(local.name)

        # If the stream retention period is different, then update it
        if created_stream.retention_period_hours > local.retention_period
          @client.decrease_stream_retention_period({
            stream_name: local.name,
            retention_period_hours: local.retention_period
          })
        elsif created_stream.retention_period_hours < local.retention_period
          @client.increase_stream_retention_period({
            stream_name: local.name,
            retention_period_hours: local.retention_period
          })
        end

        # If the created stream has tags, add them
        if !local.tags.empty?
          @client.add_tags_to_stream({
            stream_name: local.name,
            tags: local.tags
          })
        end

      end

      def update(local, diffs)
        diffs.each do |diff|
          case diff.type
          when StreamChange::SHARDS

            # See if we are splitting or merging and make sure it is a multiple of 2
            if diff.aws < diff.local
              if diff.aws != diff.local / 2.0
                puts Colors.red("Can only increase the number of shards by a factor of 2")
              else
                aws_stream = Kinesis::named_streams[local.name]

                # Split the shards 1 at a time
                aws_stream.sorted_shards.each do |shard|
                  puts Colors.blue("Splitting shard #{shard.shard_id}")

                  # The splitting point is halfway between the hash start and end
                  hash_start = shard.hash_key_range.starting_hash_key.to_i
                  hash_end = shard.hash_key_range.ending_hash_key.to_i
                  hash_split = hash_start + ((hash_end - hash_start) / 2)

                  @client.split_shard({
                    stream_name: local.name,
                    shard_to_split: shard.shard_id,
                    new_starting_hash_key: hash_split.to_s
                  })

                  # After every split we have to wait until the stream is ready
                  @client.wait_until(:stream_exists, {
                    stream_name: local.name
                  })
                end

              end
            elsif diff.aws > diff.local
              aws_stream = Kinesis::named_streams[local.name]

              if aws_stream.sorted_shards.length != local.shards * 2.0
                puts Colors.red("Can only decrease the number of shards by a factor of 2")
              else
                # Merge the sorted shards in groups of 2
                aws_stream.sorted_shards.each_slice(2) do |slice|
                  puts Colors.blue("Merging shards #{slice[0].shard_id} and #{slice[1].shard_id}")

                  @client.merge_shards({
                    stream_name: local.name,
                    shard_to_merge: slice[0].shard_id,
                    adjacent_shard_to_merge: slice[1].shard_id
                  })

                  # After every merge we have to wait until the stream is ready
                  @client.wait_until(:stream_exists, {
                    stream_name: local.name
                  })
                end

              end
            end

          when StreamChange::RETENTION
            puts Colors.blue("Updating retention period...")


            if diff.aws > local.retention_period
              @client.decrease_stream_retention_period({
                stream_name: local.name,
                retention_period_hours: local.retention_period
              })
            elsif diff.aws < local.retention_period
              @client.increase_stream_retention_period({
                stream_name: local.name,
                retention_period_hours: local.retention_period
              })
            end

            # Wait for the stream to be in an active state or shard updates will fail
            @client.wait_until(:stream_exists, {
              stream_name: local.name
            })
          when StreamChange::TAGS
            puts Colors.blue("Updating tags...")

            if !diff.tags_to_remove.empty?
              @client.remove_tags_from_stream({
                stream_name: local.name,
                tag_keys: diff.tags_to_remove.keys
              })
            end

            if !diff.tags_to_add.empty?
              @client.add_tags_to_stream({
                stream_name: local.name,
                tags: diff.tags_to_add
              })
            end

          end
        end

      end

    end
  end
end