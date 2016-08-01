require "mocks/ClientSpy"
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
      #   @attribute_name - (for sync) the name of the attribute in AWS
      #
      # Optional
      # @queue_name - the name of the queue
      # @policy - if you need to stub out a policy, provide a Hash that contains
      #   :name (the name of the policy file), and :value (the String contents
      #   of the file)
      # @test_value - supply if the correct test value should be different than
      #   @new_value
      class SingleChangeTest
        include ::RSpec::Matchers
        include ::RSpec::Mocks::ExampleMethods
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
          SQS::do_diff(get_config) do |diffs|
            diff_strings = diffs.map(&:to_s).join("\n").split("\n").map(&:strip)
            expect(diff_strings).to eq @message
          end
        end

        def self.execute_sync(&init)
          test = new(&init)
          test.execute_sync
        end

        def execute_sync
          SQS::client_spy
          SQS::do_sync(get_config) do |client|
            set_attributes = client.spied_method(:set_queue_attributes)
            expect(set_attributes.num_calls).to eq 1
            arguments = set_attributes.arguments[0]
            expect(arguments[:queue_url]).to eq Test::SQS::queue_url(@queue_name)

            if @full_test_value
              expect(arguments[:attributes]).to eq @full_test_value
            else
              expect(arguments[:attributes]).to eq ({ @attribute_name => @test_value || @new_value })
            end
          end
        end

        private

        def get_config
          keys = @path.split('.')
          overrides = {}
          keys.reduce(overrides) do |h, k|
            h[k] = if k == keys.last then @new_value else {} end
          end

          {
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
          }
        end

      end
    end
  end
end
