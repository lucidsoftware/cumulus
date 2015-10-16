require "sqs/loader/Loader"
require "sqs/models/DeadLetterConfig"
require "sqs/models/QueueDiff"

require "json"

module Cumulus
  module SQS

    # Public: An object representing configuration for a queue
    class QueueConfig
      attr_reader :name
      attr_reader :delay
      attr_reader :max_message_size
      attr_reader :message_retention
      attr_reader :policy
      attr_reader :receive_wait_time
      attr_reader :visibility_timeout
      attr_reader :dead_letter

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the queue
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @delay = json["delay"]
          @max_message_size = json["max-message-size"]
          @message_retention = json["message-retention"]
          @policy = json["policy"]
          @receive_wait_time = json["receive-wait-time"]
          @visibility_timeout = json["visibility-timeout"]
          @dead_letter = if json["dead-letter"] then DeadLetterConfig.new(json["dead-letter"]) end
        end
      end

      def to_hash
        {
          "delay" => @delay,
          "max-message-size" => @max_message_size,
          "message-retention" => @message_retention,
          "policy" => @policy,
          "receive-wait-time" => @receive_wait_time,
          "visibility-timeout" => @visibility_timeout,
          "dead-letter" => if @dead_letter then @dead_letter.to_hash end,
        }
      end

      # Public: Populate a config object with AWS configuration
      #
      # attributes - the queue attributes in AWS
      def populate!(attributes)
        @delay = attributes["DelaySeconds"]
        @max_message_size = attributes["MaximumMessageSize"]
        @message_retention = attributes["MessageRetentionPeriod"]
        @receive_wait_time = attributes["ReceiveMessageWaitTimeSeconds"]
        @visibility_timeout = attributes["VisibilityTimeout"]
        @dead_letter = if attributes["RedrivePolicy"] then DeadLetterConfig.new().populate!(attributes["RedrivePolicy"]) end

        # Policy is handled specially because we store them in a separate file locally
        # For migrating we assume the policy is the same as the queue name, otherwise this
        # attribute is not used from AWS config
        @policy = if attributes["Policy"] then @name end

        self
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the QueueDiffs that were found
      def diff(aws)
        diffs = []

        if @delay != aws.delay
          diffs << QueueDiff.new(QueueChange::DELAY, aws.delay, @delay)
        end

        if @max_message_size != aws.max_message_size
          diffs << QueueDiff.new(QueueChange::MESSAGE_SIZE, aws.max_message_size, @max_message_size)
        end

        if @message_retention != aws.message_retention
          diffs << QueueDiff.new(QueueChange::MESSAGE_RETENTION, aws.message_retention, @message_retention)
        end

        if @receive_wait_time != aws.receive_wait_time
          diffs << QueueDiff.new(QueueChange::RECEIVE_WAIT, aws.receive_wait_time, @receive_wait_time)
        end

        if @visibility_timeout != aws.visibility_timeout
          diffs << QueueDiff.new(QueueChange::VISIBILITY, aws.visibility_timeout, @visibility_timeout)
        end

        aws_dead_letter = aws.dead_letter || DeadLetterConfig.new()
        local_dead_letter = @dead_letter || DeadLetterConfig.new()
        dead_diffs = local_dead_letter.diff(aws_dead_letter)
        if !dead_diffs.empty?
          diffs << QueueDiff.new(QueueChange::DEAD, aws_dead_letter, local_dead_letter, dead_diffs)
        end

        aws_policy = SQS::queue_policy(@name)
        local_policy = if @policy then Loader.policy(@policy) end
        if local_policy != aws_policy
          diffs << QueueDiff.new(QueueChange::POLICY, aws_policy, local_policy)
        end

        diffs
      end

    end
  end
end
