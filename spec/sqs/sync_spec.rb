require "sqs/SQSUtil"
require "sqs/SingleChangeTest"

module Cumulus
  module Test
    module SQS
      describe Cumulus::SQS::Manager do
        context "The SQS module's syncing functionality" do
          it "should correctly create a new queue that's defined locally" do
            queue_name = "not-in-aws"
            SQS::client_spy
            SQS::do_sync({
              local: {queues: [{name: queue_name, value: {}}]},
              aws: {list_queues: nil},
            }) do |client|
              create = client.spied_method(:create_queue)
              expect(create.num_calls).to eq 1
              expect(create.arguments[0]).to eq ({
                :queue_name => "not-in-aws",
                :attributes => {
                  "DelaySeconds" => "",
                  "MaximumMessageSize" => "",
                  "MessageRetentionPeriod" => "",
                  "ReceiveMessageWaitTimeSeconds" => "",
                  "VisibilityTimeout" => ""
                }
              })
            end
          end

          it "should not delete queues added in AWS" do
            queue_name = "only-in-aws"
            SQS::client_spy
            SQS::do_sync({
              local: {queues: []},
              aws: {
                list_queues: {queue_urls: [SQS::queue_url(queue_name)]},
                get_queue_attributes: {},
              }
            }) do |client|
              # no calls were made to change anything
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:list_queues).nil?).to eq false
              expect(client.spied_method(:get_queue_attributes).nil?).to eq false
            end
          end

          it "should update delay" do
            SingleChangeTest.execute_sync do
              @path = "delay"
              @new_value = SQS::DEFAULT_QUEUE_DELAY - 1
              @previous_value = SQS::DEFAULT_QUEUE_DELAY
              @test_value = @new_value.to_s
              @attribute_name = "DelaySeconds"
            end
          end

          it "should update max-message-size" do
            SingleChangeTest.execute_sync do
              @path = "max-message-size"
              @new_value = SQS::DEFAULT_QUEUE_MESSAGE_SIZE - 1
              @previous_value = SQS::DEFAULT_QUEUE_MESSAGE_SIZE
              @attribute_name = "MaximumMessageSize"
              @test_value = @new_value.to_s
            end
          end

          it "should update message-retention" do
            SingleChangeTest.execute_sync do
              @path = "message-retention"
              @new_value = SQS::DEFAULT_QUEUE_MESSAGE_RETENTION - 1
              @previous_value = SQS::DEFAULT_QUEUE_MESSAGE_RETENTION
              @attribute_name = "MessageRetentionPeriod"
              @test_value = @new_value.to_s
            end
          end

          it "should update receive-wait-time" do
            SingleChangeTest.execute_sync do
              @path = "receive-wait-time"
              @new_value = SQS::DEFAULT_QUEUE_WAIT_TIME - 1
              @previous_value = SQS::DEFAULT_QUEUE_WAIT_TIME
              @attribute_name = "ReceiveMessageWaitTimeSeconds"
              @test_value = @new_value.to_s
            end
          end

          it "should update the policy" do
            new_value = "example-policy-2"
            new_contents = "{\"a\":\"b\"}"
            SingleChangeTest.execute_sync do
              @path = "policy"
              @policy = {
                name: new_value,
                value: new_contents,
              }
              @new_value = new_value
              @previous_value = JSON.parse(SQS::DEFAULT_QUEUE_POLICY)
              @attribute_name = "Policy"
              @test_value = JSON.generate(JSON.parse(new_contents))
            end
          end

          it "should update the dead-letter target" do
            SingleChangeTest.execute_sync do
              @path = "dead-letter.target"
              @new_value = SQS::DEFAULT_DEAD_LETTER_TARGET + "a"
              @previous_value = SQS::DEFAULT_DEAD_LETTER_TARGET
              @full_test_value = {
                "RedrivePolicy" => JSON.generate({
                  "deadLetterTargetArn" => @new_value,
                  "maxReceiveCount" => SQS::DEFAULT_DEAD_LETTER_RECEIVES
                })
              }
            end
          end

          it "should update dead-letter max-receives" do
            SingleChangeTest.execute_sync do
              @path = "dead-letter.max-receives"
              @new_value = SQS::DEFAULT_DEAD_LETTER_RECEIVES + 1
              @previous_value = SQS::DEFAULT_DEAD_LETTER_RECEIVES
              @full_test_value = {
                "RedrivePolicy" => JSON.generate({
                  "deadLetterTargetArn" => SQS::DEFAULT_DEAD_LETTER_TARGET,
                  "maxReceiveCount" => @new_value
                })
              }
            end
          end

        end
      end
    end
  end
end
