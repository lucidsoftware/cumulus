require "common/manager/Manager"
require "conf/Configuration"
require "s3/loader/Loader"
require "s3/models/BucketDiff"
require "s3/S3"
require "util/Colors"

require "aws-sdk"

module Cumulus
  module S3
    class Manager < Common::Manager
      def resource_name
        "Bucket"
      end

      def local_resources
        Hash[Loader.buckets.map { |bucket| [bucket.name, bucket] }]
      end

      def aws_resources
        S3.buckets
      end

      def unmanaged_diff(aws)
        BucketDiff.unmanaged(aws)
      end

      def added_diff(local)
        BucketDiff.added(local)
      end

      def diff_resource(local, aws)
        full_aws = full_bucket(aws.name)
        local.diff(full_aws)
      end

      def create(local)
      end

      def update(local, diffs)
      end

      private

      # Internal: Get the full data for a bucket. Lazily loads resources only once.
      #
      # bucket_name - the name of the bucket to get
      #
      # Returns the full bucket
      def full_bucket(bucket_name)
        @full_buckets ||= Hash.new

        @full_buckets[bucket_name] ||= Aws::S3::Bucket.new(name: bucket_name, client: S3::client)
      end
    end
  end
end
