require "aws-sdk-s3"
require "json"
require "deepsort"

module AwsExtensions
  module S3
    module BucketPolicy
      # Public: Method that will either return the bucket policy, or an empty
      # string if there is no policy.
      #
      # Returns the policy as a string.
      def policy_string
        # fetch the sorted policy
        hash = policy_hash
        # check if policy exists
        unless hash.nil?
          # convert the policy to string
          JSON.generate(hash)
        else
          # if no policy exists, return an empty string
          ""
        end
      end

      # Public: Method returns the bucket policy as a sorted hash
      # if no policy exists, returns nil
      def policy_hash
        # rescue and ignore all excpetions related to no policy existing
        # We have to do this because catching an exception is the ONLY way to determine if there is a policy.
        JSON.parse(policy.string).deep_sort
      rescue Aws::S3::Errors::NoSuchBucketPolicy
        nil
      end
    end
  end
end
