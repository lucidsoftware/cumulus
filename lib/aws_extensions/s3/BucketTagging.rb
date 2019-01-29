require "aws-sdk-s3"

module AwsExtensions
  module S3
    module BucketTagging
      # Public: Safely get the tag set for the BucketTagging object (ignore the
      # exception that occurs when there aren't any tags)
      #
      # Returns the tags or an empty array if there are none
      def safe_tags
        tag_set
      rescue Aws::S3::Errors::NoSuchTagSet
        []
      end
    end
  end
end
