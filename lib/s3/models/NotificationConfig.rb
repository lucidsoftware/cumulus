require "lambda/Lambda"
require "s3/models/NotificationDiff"
require "sns/SNS"
require "sqs/SQS"

module Cumulus
  module S3
    class NotificationConfig
      attr_reader :name
      attr_reader :prefix
      attr_reader :suffix
      attr_reader :target
      attr_reader :triggers
      attr_reader :type

      # Public: Constructor
      #
      # json - a hash representing the JSON configuration. Expects to be passed
      #        an object from the "notifications" array of S3 bucket configuration.
      def initialize(json = nil)
        if json
          @name = json["name"]
          @prefix = json["prefix"]
          @suffix = json["suffix"]
          @target = json["target"]
          @triggers = (json["triggers"] || []).map { |t| "s3:#{t}" }
          @type = json["type"]
        end
      end

      # Public: Populate this NotificationConfig with the values in an AWS configuration
      # of events.
      #
      # aws - the aws object to populate from
      def populate!(aws)
        @name = aws.id
        @prefix = aws.filter.key.filter_rules.find { |r| r.name.downcase == "prefix" }.value rescue nil
        @suffix = aws.filter.key.filter_rules.find { |r| r.name.downcase == "suffix" }.value rescue nil
        @triggers = aws.events
        if aws.respond_to? "queue_arn"
          @type = "sqs"
          @target = aws.queue_arn[(aws.queue_arn.rindex(":") + 1)..-1]
        elsif aws.respond_to? "lambda_function_arn"
          @type = "lambda"
          @target = aws.lambda_function_arn[(aws.lambda_function_arn.rindex(":") + 1)..-1]
        else
          @type = "sns"
          @target = aws.topic_arn[(aws.topic_arn.rindex(":") + 1)..-1]
        end
      end

      # Public: Produce an AWS compatible hash for this NotificationConfig.
      #
      # Returns the hash.
      def to_aws
        if @type == "sns"
          topic_arn = SNS.get_aws(@target)
        elsif @type == "sqs"
          queue_arn = SQS.get_arn(@target)
        elsif @type == "lambda"
          lambda_function_arn = Lambda.get_aws(@target).function_arn
        end
        {
          id: @name,
          events: @triggers,
          topic_arn: topic_arn,
          queue_arn: queue_arn,
          lambda_function_arn: lambda_function_arn,
          filter: {
            key: {
              filter_rules: [
                if @prefix then {
                  name: "prefix",
                  value: @prefix
                } end,
                if @suffix then {
                  name: "suffix",
                  value: @suffix
                } end
              ].reject { |e| e.nil? }
            }
          }
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce an array of differences between this local configuration
      # and the configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the NotificationDiffs that were found
      def diff(aws)
        diffs = []

        if @prefix != aws.prefix
          diffs << NotificationDiff.new(NotificationChange::PREFIX, aws, self)
        end
        if @suffix != aws.suffix
          diffs << NotificationDiff.new(NotificationChange::SUFFIX, aws, self)
        end
        if @triggers.sort != aws.triggers.sort
          diffs << NotificationDiff.new(NotificationChange::TRIGGERS, aws, self)
        end
        if @type != aws.type
          diffs << NotificationDiff.new(NotificationChange::TYPE, aws, self)
        end
        if @target != aws.target
          diffs << NotificationDiff.new(NotificationChange::TARGET, aws, self)
        end

        diffs
      end

      # Public: Check NotificationConfig equality with other objects.
      #
      # other - the other object to check
      #
      # Returns whether this NotificationConfig is equal to `other`
      def ==(other)
        if !other.is_a? NotificationConfig or
            @name != other.name or
            @prefix != other.prefix or
            @suffix != other.suffix or
            @target != other.target or
            @triggers.sort != other.triggers.sort or
            @type != other.type
          false
        else
          true
        end
      end

      # Public: Check if this NotificationConfig is not equal to the other object
      #
      # other - the other object to check
      #
      # Returns whether this NotificationConfig is not equal to `other`
      def !=(other)
        !(self == other)
      end
    end
  end
end
