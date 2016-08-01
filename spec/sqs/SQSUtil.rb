require "conf/Configuration"
require "mocks/MockedConfiguration"
Cumulus::Configuration.send :include, Cumulus::Test::MockedConfiguration

require "common/BaseLoader"
require "mocks/MockedLoader"
Cumulus::Common::BaseLoader.send :include, Cumulus::Test::MockedLoader

require "common/manager/Manager"
require "util/ManagerUtil"
Cumulus::Common::Manager.send :include, Cumulus::Test::ManagerUtil

require "util/StatusCodes"
require "mocks/MockedStatusCodes"
Cumulus::StatusCodes.send :include, Cumulus::Test::MockedStatusCodes

require "aws-sdk"
require "json"
require "sqs/manager/Manager"
require "sqs/SQS"
require "util/DeepMerge"

module Cumulus
  module Test
    # Monkey patch Cumulus::SQS such that the cached values from the AWS client
    # can be reset between tests.
    module ResetSQS
      def self.included(base)
        base.instance_eval do
          def reset_queue_urls
            @queue_urls = nil
          end

          def reset_queue_attributes
            @queue_attributes = nil
          end

          def client=(client)
            @@client = client
          end
        end
      end
    end

    # Monkey patch Cumulus::SQS such that the queue_arns contain the ARN for the
    # default dead letter target
    module DeadLetterArn
      def self.included(base)
        base.instance_eval do
          singleton_class.send(:alias_method, :original_queue_arns, :queue_arns)

          def queue_arns
            arns = original_queue_arns
            arns[SQS::DEFAULT_DEAD_LETTER_TARGET] = SQS::DEFAULT_DEAD_LETTER_TARGET
            arns[SQS::DEFAULT_DEAD_LETTER_TARGET + "a"] = SQS::DEFAULT_DEAD_LETTER_TARGET + "a"
            arns
          end
        end
      end
    end

    module SQS
      @queue_directory = "/mocked/sqs/queues"
      @policy_directory = "/mocked/sqs/policies"
      @default_policy_name = "example-policy"

      DEFAULT_QUEUE_DELAY = 0
      DEFAULT_QUEUE_MESSAGE_SIZE = 262144
      DEFAULT_QUEUE_MESSAGE_RETENTION = 345600
      DEFAULT_QUEUE_WAIT_TIME = 0
      DEFAULT_QUEUE_VISIBILITY = 30
      DEFAULT_QUEUE_POLICY = "{}"
      DEFAULT_DEAD_LETTER_TARGET = "queue-2"
      DEFAULT_DEAD_LETTER_RECEIVES = 3

      @default_queue_attributes = {
        "delay" => DEFAULT_QUEUE_DELAY,
        "max-message-size" => DEFAULT_QUEUE_MESSAGE_SIZE,
        "message-retention" => DEFAULT_QUEUE_MESSAGE_RETENTION,
        "policy" => @default_policy_name,
        "receive-wait-time" => DEFAULT_QUEUE_WAIT_TIME,
        "visibility-timeout" => DEFAULT_QUEUE_VISIBILITY,
        "dead-letter" => {
          "target" => DEFAULT_DEAD_LETTER_TARGET,
          "max-receives" => DEFAULT_DEAD_LETTER_RECEIVES
        },
      }

      @default_aws_queue_attributes = {
        "DelaySeconds" => "#{DEFAULT_QUEUE_DELAY}",
        "MaximumMessageSize" => "#{DEFAULT_QUEUE_MESSAGE_SIZE}",
        "MessageRetentionPeriod" => "#{DEFAULT_QUEUE_MESSAGE_RETENTION}",
        "ReceiveMessageWaitTimeSeconds" => "#{DEFAULT_QUEUE_WAIT_TIME}",
        "VisibilityTimeout" => "#{DEFAULT_QUEUE_VISIBILITY}",
        "Policy" => DEFAULT_QUEUE_POLICY,
        "RedrivePolicy" => JSON.generate({
          "deadLetterTargetArn" => DEFAULT_DEAD_LETTER_TARGET,
          "maxReceiveCount" => "#{DEFAULT_DEAD_LETTER_RECEIVES}"
        }),
      }

      # Public: Reset the SQS module in between tests
      def self.reset
        Cumulus::Configuration.stub

        if !Cumulus::SQS.respond_to? :reset_queue_urls
          Cumulus::SQS.send :include, Cumulus::Test::ResetSQS
        end

        if !Cumulus::SQS.respond_to? :original_queue_arns
          Cumulus::SQS.send :include, Cumulus::Test::DeadLetterArn
        end

        Cumulus::SQS::reset_queue_urls
        Cumulus::SQS::reset_queue_attributes
      end

      # Public: Returns the String path of the "directory" that contains the
      # policies.
      def self.policy_directory
        @policy_directory
      end

      # Public: Returns a Hash containing default queue attributes for a local
      # queue definition with values overridden by the Hash passed in.
      #
      # overrides - optionally provide a Hash that will override default
      #   attributes
      def self.default_queue_attributes(overrides = nil)
        Util::DeepMerge.deep_merge(@default_queue_attributes, overrides)
      end

      # Public: Returns a Hash containing default queue attributes for an AWS
      # queue definition with values overridden by the Hash passed in.
      #
      # overrides - optionally provide a Hash that will override default
      #   attributes
      def self.default_aws_queue_attributes(overrides = nil)
        Util::DeepMerge.deep_merge(@default_aws_queue_attributes, overrides)
      end

      # Public: Returns a fake queue url for a queue name
      def self.queue_url(queue_name)
        "http://sqs.us-east-1.amazonaws.com/123456789012/#{queue_name}"
      end

      # Public: Diff stubbed local configuration and stubbed AWS configuration.
      #
      # config - a Hash that contains two values, :local and :aws, which contain
      #   the values to stub out.
      #     :local contains :queues which is an Array of queues to stub the
      #       directory with, and :policies, which is an Array of policy files
      #       to stub out.
      #     :aws is a hash of method names from the AWS Client to stub mapped
      #       to the value the AWS Client should return
      # test  - a block that tests the diffs returned by the Manager class
      def self.do_diff(config, &test)
        self.prepare_test(config)

        # get the diffs and call the tester to determine the result of the test
        manager = Cumulus::SQS::Manager.new
        diffs = manager.diff_strings
        test.call(diffs)
      end

      # Public: Sync stubbed local configuration and stubbed AWS configuration.
      #
      # config - a Hash that contains two values, :local and :aws, which contain
      #   the values to stub out.
      #     :local contains :queues which is an Array of queues to stub the
      #       directory with, and :policies, which is an Array of policy files
      #       to stub out.
      #     :aws is a hash of method names from the AWS Client to stub mapped
      #       to the value the AWS Client should return
      # test - a block that tests the AWS Client after the syncing has been done
      def self.do_sync(config, &test)
        self.prepare_test(config)

        # get the diffs and call the tester to determine the result of the test
        manager = Cumulus::SQS::Manager.new
        manager.sync
        test.call(Cumulus::SQS::client)
      end

      private

      def self.prepare_test(config)
        self.reset
        # we'll always just stub out the default policy
        Cumulus::Common::BaseLoader.stub_file(
          File.join(@policy_directory, @default_policy_name),
          DEFAULT_QUEUE_POLICY
        )

        # stub out local queues
        if config[:local][:queues]
          Cumulus::Common::BaseLoader.stub_directory(
            @queue_directory, config[:local][:queues]
          )
        end

        # stub out local policies
        if config[:local][:policies]
          config[:local][:policies].each do |policy|
            Cumulus::Common::BaseLoader.stub_file(
              File.join(SQS::policy_directory, policy[:name]),
              policy[:value]
            )
          end
        end

        # stub out aws responses
        config[:aws].map do |call, value|
          if value
            Cumulus::SQS::client.stub_responses(call, value)
          else
            Cumulus::SQS::client.stub_responses(call)
          end
        end
      end

      def self.client_spy
        if !Cumulus::SQS::client.respond_to? :have_received
          Cumulus::SQS::client = ClientSpy.new(Cumulus::SQS::client)
        end
        Cumulus::SQS::client.clear_spy
      end

    end
  end
end
