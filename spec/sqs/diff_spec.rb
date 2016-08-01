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
              @new_value = SQS::DEFAULT_QUEUE_DELAY - 1
              @previous_value = SQS::DEFAULT_QUEUE_DELAY
              @message = [
                "Delay",
                "AWS - #{@previous_value} seconds",
                "Local - #{@new_value} seconds"
              ]
            end
          end

          it "should detect changes in max-message-size" do
            SingleChangeTest.execute do
              @path = "max-message-size"
              @new_value = SQS::DEFAULT_QUEUE_MESSAGE_SIZE - 1
              @previous_value = SQS::DEFAULT_QUEUE_MESSAGE_SIZE
              @message = [
                "Max Message Size",
                "AWS - #{@previous_value} bytes",
                "Local - #{@new_value} bytes"
              ]
            end
          end

          it "should detect changes in message-retention" do
            SingleChangeTest.execute do
              @path = "message-retention"
              @new_value = SQS::DEFAULT_QUEUE_MESSAGE_RETENTION - 1
              @previous_value = SQS::DEFAULT_QUEUE_MESSAGE_RETENTION
              @message = [
                "Message Retention Period",
                "AWS - #{@previous_value} seconds",
                "Local - #{@new_value} seconds"
              ]
            end
          end

          it "should detect changes in receive-wait-time" do
            SingleChangeTest.execute do
              @path = "receive-wait-time"
              @new_value = SQS::DEFAULT_QUEUE_WAIT_TIME - 1
              @previous_value = SQS::DEFAULT_QUEUE_WAIT_TIME
              @message = [
                "Receive Wait Time",
                "AWS - #{@previous_value} seconds",
                "Local - #{@new_value} seconds"
              ]
            end
          end

          it "should detect changes in visibility-timeout" do
            SingleChangeTest.execute do
              @path = "visibility-timeout"
              @new_value = SQS::DEFAULT_QUEUE_VISIBILITY - 1
              @previous_value = SQS::DEFAULT_QUEUE_VISIBILITY
              @message = [
                "Message Visibility",
                "AWS - #{@previous_value} seconds",
                "Local - #{@new_value} seconds"
              ]
            end
          end

          it "should detect changes in policy" do
            new_value = "example-policy-2"
            new_contents = "{\"a\":\"b\"}"
            SingleChangeTest.execute do
              @path = "policy"
              @policy = {
                name: new_value,
                value: new_contents,
              }
              @new_value = new_value
              @previous_value = JSON.parse(SQS::DEFAULT_QUEUE_POLICY)
              test_value = JSON.pretty_generate(JSON.parse(new_contents)).split("\n").map(&:strip)
              @message = [
                "Policy:",
                "Removing:",
                JSON.pretty_generate(@previous_value).split("\n"),
                "Adding:",
                test_value
              ].flatten
            end
          end

          it "should detect changes in dead-letter target" do
            SingleChangeTest.execute do
              @path = "dead-letter.target"
              @new_value = SQS::DEFAULT_DEAD_LETTER_TARGET + "a"
              @previous_value = SQS::DEFAULT_DEAD_LETTER_TARGET
              @message = [
                "Dead Letter Queue",
                "Target:",
                "AWS - #{@previous_value}",
                "Local - #{@new_value}"
              ]
            end
          end

          it "should detect changes in dead-letter max-receives" do
            SingleChangeTest.execute do
              @path = "dead-letter.max-receives"
              @new_value = SQS::DEFAULT_DEAD_LETTER_RECEIVES + 1
              @previous_value = SQS::DEFAULT_DEAD_LETTER_RECEIVES
              @message = [
                "Dead Letter Queue",
                "Max Receive Count:",
                "AWS - #{@previous_value}",
                "Local - #{@new_value}"
              ]
            end
          end
        end
      end
    end
  end
end
