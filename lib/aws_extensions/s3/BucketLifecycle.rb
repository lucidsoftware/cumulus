require "s3/models/LifecycleConfig"
require "aws-sdk-s3"

module AwsExtensions
  module S3
    module BucketLifecycle
      # Public: Convert this Aws::S3::BucketLifecycle into an array of
      # Cumulus::S3::LifecycleConfig
      #
      # Returns the array of LifecycleConfig
      def to_cumulus
        Hash[rules.reject { |r| r.status.downcase != "enabled" }.map do |rule|
          cumulus = Cumulus::S3::LifecycleConfig.new
          cumulus.populate!(rule)
          [cumulus.name, cumulus]
        end]
      rescue Aws::S3::Errors::NoSuchLifecycleConfiguration
        {}
      end
    end
  end
end
