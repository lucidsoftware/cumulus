require "sqs/SQSUtil"
require "sqs/models/QueueDiff"

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
      #   @new_value - the value to change to in the local configuration
      #   @previous_value - the value to change from
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
          @queue_name = "queue-name"
          instance_eval(&init)
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
            diff_strings = diffs.map(&:to_s).join("\n").split("\n").map(&:strip)
            expect(diff_strings).to eq @message
          end
        end

      end
    end
  end
end
