require "sqs/SQSUtil"
require "sqs/SingleChangeTest"

module Cumulus
  module Test
    module SQS
      describe Cumulus::SQS::Manager do
        context "The SQS module's diffing functionality" do
          it "should detect new queues defined locally" do
            queue_name = "not-in-aws"
            SQS::do_diff({
              local: {queues: [{name: queue_name, value: {}}]},
              aws: {list_queues: nil},
            }) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs[0].to_s).to eq "Queue #{queue_name} will be created."
            end
          end

          it "should detect new queues added in AWS" do
            queue_name = "only-in-aws"
            SQS::do_diff({
              local: {queues: []},
              aws: {
                list_queues: {queue_urls: [SQS::queue_url(queue_name)]},
                get_queue_attributes: {},
              }
            }) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs[0].to_s).to eq "Queue #{queue_name} is not managed by Cumulus."
            end
          end

          it "should detect changes in delay" do
            SingleChangeTest.execute do
              @path = "delay"
              @getter = @queue_delay_getter
              @value = SQS::DEFAULT_QUEUE_DELAY - 1
              @previous_value = SQS::DEFAULT_QUEUE_DELAY
            end
          end

          it "should detect changes in max-message-size" do
            SingleChangeTest.execute do
              @path = "max-message-size"
              @getter = @queue_message_size_getter
              @new_value = SQS::DEFAULT_QUEUE_MESSAGE_SIZE - 1
              @previous_value = SQS::DEFAULT_QUEUE_MESSAGE_SIZE
            end
          end

          it "should detect changes in message-retention" do
            SingleChangeTest.execute do
              @path = "message-retention"
              @getter = @queue_message_retention_getter
              @new_value = SQS::DEFAULT_QUEUE_MESSAGE_RETENTION - 1
              @previous_value = SQS::DEFAULT_QUEUE_MESSAGE_RETENTION
            end
          end

          it "should detect changes in receive-wait-time" do
            SingleChangeTest.execute do
              @path = "receive-wait-time"
              @getter = @queue_wait_time_getter
              @new_value = SQS::DEFAULT_QUEUE_WAIT_TIME - 1
              @previous_value = SQS::DEFAULT_QUEUE_WAIT_TIME
            end
          end

          it "should detect changes in visibility-timeout" do
            SingleChangeTest.execute do
              @path = "visibility-timeout"
              @getter = @queue_visibility_getter
              @new_value = SQS::DEFAULT_QUEUE_VISIBILITY - 1
              @previous_value = SQS::DEFAULT_QUEUE_VISIBILITY
            end
          end

          it "should detect changes in policy" do
            new_value = "example-policy-2"
            new_contents = "{\"a\":\"b\"}"
            SingleChangeTest.execute do
              @path = "policy"
              @getter = @queue_policy_getter
              @policy = {
                name: new_value,
                value: new_contents,
              }
              @new_value = new_value
              @previous_value = JSON.parse(SQS::DEFAULT_QUEUE_POLICY)
              @test_value = JSON.parse(new_contents)
            end
          end

          it "should detect changes in dead-letter target" do
            SingleChangeTest.execute do
              @path = "dead-letter.target"
              @getter = @queue_dead_letter_getter.and_then @dead_letter_target_getter
              @new_value = SQS::DEFAULT_DEAD_LETTER_TARGET + "a"
              @previous_value = SQS::DEFAULT_DEAD_LETTER_TARGET
            end
          end

          it "should detect changes in dead-letter max-receives" do
            SingleChangeTest.execute do
              @path = "dead-letter.max-receives"
              @getter = @queue_dead_letter_getter.and_then @dead_letter_max_receives_getter
              @new_value = SQS::DEFAULT_DEAD_LETTER_RECEIVES + 1
              @previous_value = SQS::DEFAULT_DEAD_LETTER_RECEIVES
            end
          end
        end
      end
    end
  end
end
