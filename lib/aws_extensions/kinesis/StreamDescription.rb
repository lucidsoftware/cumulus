module AwsExtensions
  module Kinesis
    module StreamDescription

      # Public: Get the list of open shards sorted by hash key range, ascending
      def sorted_shards
        self.shards.select { |shard| shard.sequence_number_range.ending_sequence_number.nil? }
                   .sort_by { |shard| shard.hash_key_range.starting_hash_key.to_i }
      end
    end
  end
end
