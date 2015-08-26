require "s3/models/LifecycleConfig"

module AwsExtensions
  module S3
    module BucketLifecycle
      # Public: Convert this Aws::S3::BucketLifecycle into an array of
      # Cumulus::S3::LifecycleConfig
      #
      # Returns the array of LifecycleConfig
      def to_cumulus
        Hash[rules.map do |rule|
          cumulus = Cumulus::S3::LifecycleConfig.new
          cumulus.populate!(rule)
          [cumulus.name, cumulus]
        end]
      end
    end
  end
end
