require "sqs/SQSUtil"
require "sqs/models/QueueDiff"
require "util/Composable"

module Cumulus
  module Test
    module SQS
      # Public: A helper that makes defining a test for changing a single queue
      # value as simple as defining some attributes. Automatically stubs local
      # and AWS config and then tests that expected values are returned by the
      # diffing function. The following attributes are available.
      #
      # Required
      #   @path - the path in the local configuration to the value to override.
      #     Each level in the JSON should be separated with "."
      #   @getter - a function that will access the diff that contains the change.
      #     SingleChangeTest provides Composable getters for getting any change
      #     in a queue that will also enforce diff types while descending into
      #     the diff structure
      #   @new_value - the value to change to in the local configuration
      #   @previous_value - the value to change from
      #   @test_value - if the final value in the diff is not equal to @new_value,
      #     provide @test_value to override the value to test the diff against
      #   @policy - if you need to stub out a policy, provide a Hash that contains
      #     :name (the name of the policy file), and :value (the String contents
      #     of the file)
      #
      # Optional
      # @queue_name - the name of the queue
      class SingleChangeTest
        include ::RSpec::Matchers
        include Cumulus::SQS::QueueChange
        include Cumulus::SQS::DeadLetterChange

        def initialize(&init)
          @queue_delay_getter = queue_diff(DELAY)
          @queue_message_size_getter = queue_diff(MESSAGE_SIZE)
          @queue_message_retention_getter = queue_diff(MESSAGE_RETENTION)
          @queue_wait_time_getter = queue_diff(RECEIVE_WAIT)
          @queue_visibility_getter = queue_diff(VISIBILITY)
          @queue_policy_getter = queue_diff(POLICY)
          @queue_dead_letter_getter = queue_diff(DEAD)

          @dead_letter_max_receives_getter = dead_letter_diff(RECEIVE)
          @dead_letter_target_getter = dead_letter_diff(TARGET)

          @queue_name = "queue-name"
          instance_eval(&init)
          execute()
        end

        def queue_diff(change_type)
          Cumulus::Test::Composable.new do |diffs|
            expect(diffs.size).to eq 1
            expect(diffs.first.type).to eq change_type
            diffs.first
          end
        end

        def dead_letter_diff(change_type)
          Cumulus::Test::Composable.new do |diff|
            expect(diff.changes.size).to eq 1
            expect(diff.changes.first.type).to eq change_type
            diff.changes.first
          end
        end

        def self.execute(&init)
          test = new(&init)
          test.execute
        end

        def execute
          keys = @path.split('.')
          overrides = {}
          keys.reduce(overrides) do |h, k|
            h[k] = if k == keys.last then @new_value else {} end
          end
          SQS::do_diff({
            local: {
              queues: [{
                name: @queue_name,
                value: SQS::default_queue_attributes(overrides)
              }],
              policies: if @policy then [{
                name: @policy[:name],
                value: @policy[:value],
              }] end
            },
            aws: {
              list_queues: {queue_urls: [SQS::queue_url(@queue_name)]},
              get_queue_attributes: {attributes: SQS::default_aws_queue_attributes}
            }
          }) do |diffs|
            diff = @getter.call(diffs)
            expect(diff.aws).to eq @previous_value
            if @test_value
              expect(diff.local).to eq @test_value
            else
              expect(diff.local).to eq @new_value
            end
          end
        end
      end
    end
  end
end
