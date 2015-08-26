require "aws-sdk"

module AwsExtensions
  module S3
    module BucketPolicy
      # Public: Method that will either return the bucket policy, or an empty
      # string if there is no policy. We have to do this because catching an
      # exception is the ONLY way to determine if there is a policy.
      #
      # Returns the policy as a string.
      def policy_string
        policy.string
      rescue Aws::S3::Errors::NoSuchBucketPolicy
        ""
      end
    end
  end
end
