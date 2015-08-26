require "aws-sdk"

module AwsExtensions
  module S3
    module BucketCors
      # Public: Method that will return the bucket cors. We have this method
      # because if there are no CORS rules, an exception is thrown.
      #
      # Returns an array of Aws::S3::CORSRule
      def rules
        cors_rules
      rescue Aws::S3::Errors::NoSuchCORSConfiguration
        []
      end
    end
  end
end
