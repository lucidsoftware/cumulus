require "sqs/models/DeadLetterDiff"

require "json"

module Cumulus
  module SQS

    # Public: An object representing configuration for a queue's dead letter options
    class DeadLetterConfig
      attr_reader :target
      attr_reader :max_receives

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for dead letter options
      def initialize(json = nil)
        if !json.nil?
          @target = json["target"]
          @max_receives = json["max-receives"]
        end
      end

      def to_hash
        {
          "target" => @target,
          "max-receives" => @max_receives,
        }
      end

      def to_aws
        {
          "deadLetterTargetArn" => SQS::queue_arns[@target],
          "maxReceiveCount" => @max_receives
        }
      end

      # Public: Populate a config object with AWS configuration
      #
      # aws - the JSON string containing dead letter attributes in AWS
      def populate!(aws)
        attributes = JSON.parse(URI.decode(aws))

        @target = SQS::queue_arns.key(attributes["deadLetterTargetArn"])
        @max_receives = attributes["maxReceiveCount"]

        self
      end

      # Public: Produce an array of differences between two DeadLetterConfig objects
      #
      # aws - the DeadLetterConfig object built from aws config
      #
      # Returns an array of the DeadLetterDiffs that were found
      def diff(aws)
        diffs = []

        if @target != aws.target
          diffs << DeadLetterDiff.new(DeadLetterChange::TARGET, aws.target, @target)
        end

        if @max_receives != aws.max_receives
          diffs << DeadLetterDiff.new(DeadLetterChange::RECEIVE, aws.max_receives, @max_receives)
        end

        diffs
      end

    end
  end
end
