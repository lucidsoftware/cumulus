module Cumulus
  module S3
    class LoggingConfig
      attr_reader :enabled
      attr_reader :target_bucket
      attr_reader :prefix

      # Public: Constructor
      #
      # json - a hash representing the JSON configuration. Expects to be handed
      #        the 'logging' node of S3 configuration.
      def initialize(json = nil)
        if json
          @enabled = json["enabled"] || false
          @target_bucket = json["target-bucket"]
          @prefix = json["prefix"]
        end
      end

      # Public: Populate this LoggingConfig with the values in an AWS BucketLogging
      # object.
      #
      # aws - the aws object to populate from
      def populate!(aws)
        @enabled = aws.enabled

        if @enabled
          @target_bucket = aws.logging_enabled.target_bucket
          @prefix = aws.logging_enabled.target_prefix
        end
      end

      # Public: Check LoggingConfig equality with other objects
      #
      # other - the other object to check
      #
      # Returns whether this LoggingConfig is equal to `other`
      def ==(other)
        if !other.is_a? LoggingConfig or
            @enabled != other.enabled or
            @target_bucket != other.target_bucket or
            @prefix != other.prefix
          false
        else
          true
        end
      end

      # Public: Check if this LoggingConfig is not equal to the other object
      #
      # other - the other object to check
      #
      # Returns whether this LoggingConfig is not equal to `other`
      def !=(other)
        !(self == other)
      end

      def to_s
        if !@enabled
          "Not enabled"
        elsif @target_bucket and @prefix
          "Target bucket: #{@target_bucket} with prefix #{@prefix}"
        elsif @target_bucket
          "Target bucket: #{@target_bucket}"
        end
      end
    end
  end
end
