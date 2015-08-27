require "s3/models/LifecycleDiff"

module Cumulus
  module S3
    class LifecycleConfig
      attr_reader :name
      attr_reader :prefix
      attr_reader :days_until_glacier
      attr_reader :days_until_delete
      attr_reader :past_days_until_glacier
      attr_reader :past_days_until_delete

      # Public: Constructor
      #
      # json - a hash representing the JSON configuration. Expects to be passed
      #        an object from the "lifecycle" array of S3 bucket configuration.
      def initialize(json = nil)
        if json
          @name = json["name"]
          @prefix = json["prefix"]
          @days_until_glacier = json["days-until-glacier"]
          @days_until_delete = json["days-until-delete"]
          if json["past-versions"]
            @past_days_until_glacier = json["past-versions"]["days-until-glacier"]
            @past_days_until_delete = json["past-versions"]["days-until-delete"]
          end
        end
      end

      # Public: Populate this LifecycleConfig with the values in an AWS
      # Configuration object.
      #
      # aws - the aws object to populate from
      def populate!(aws)
        @name = aws.id
        @prefix = aws.prefix
        @days_until_glacier = (aws.transition.days unless aws.transition.storage_class.downcase != "glacier") rescue nil
        @days_until_delete = aws.expiration.days rescue nil
        @past_days_until_glacier = (aws.noncurrent_version_transition.noncurrent_days unless aws.noncurrent_version_transition.storage_class.downcase != "glacier") rescue nil
        @past_days_until_delete = aws.noncurrent_version_expiration.noncurrent_days rescue nil
      end

      # Public: Produce an AWS hash representing this LifecycleConfig.
      #
      # Returns the hash.
      def to_aws
        {
          id: @name,
          prefix: @prefix,
          status: "Enabled",
          transition: if @days_until_glacier then {
            days: @days_until_glacier,
            storage_class: "GLACIER"
          } end,
          expiration: if @days_until_delete then {
            days: @days_until_delete
          } end,
          noncurrent_version_transition: if @past_days_until_glacier then {
            noncurrent_days: @past_days_until_glacier,
            storage_class: "GLACIER"
          } end,
          noncurrent_version_expiration: if @past_days_until_delete then {
            noncurrent_days: @past_days_until_delete
          } end
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce an array of differences between this local configuration
      # and the configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of LifecycleDiffs that were found
      def diff(aws)
        diffs = []

        if @prefix != aws.prefix
          diffs << LifecycleDiff.new(LifecycleChange::PREFIX, aws, self)
        end
        if @days_until_glacier != aws.days_until_glacier
          diffs << LifecycleDiff.new(LifecycleChange::DAYS_UNTIL_GLACIER, aws, self)
        end
        if @days_until_delete != aws.days_until_delete
          diffs << LifecycleDiff.new(LifecycleChange::DAYS_UNTIL_DELETE, aws, self)
        end
        if @past_days_until_glacier != aws.past_days_until_glacier
          diffs << LifecycleDiff.new(LifecycleChange::PAST_UNTIL_GLACIER, aws, self)
        end
        if @past_days_until_delete != aws.past_days_until_delete
          diffs << LifecycleDiff.new(LifecycleChange::PAST_UNTIL_DELETE, aws, self)
        end

        diffs
      end

      # Public: Check LifecycleConfig equality with other objects.
      #
      # other - the other object to check
      #
      # Returns whether this LifecycleConfig is equal to `other`
      def ==(other)
        if !other.is_a? LifecycleConfig or
            @name != other.name or
            @prefix != other.prefix or
            @days_until_glacier != other.days_until_glacier or
            @days_until_delete != other.days_until_delete or
            @past_days_until_glacier != other.past_days_until_glacier or
            @past_days_until_delete != other.past_days_until_delete
          false
        else
          true
        end
      end

      # Public: Check if this LifecycleConfig is not equal to the other object
      #
      # other - the other object to check
      #
      # Returns whether this LifecycleConfig is not equal to `other`
      def !=(other)
        !(self == other)
      end
    end
  end
end
