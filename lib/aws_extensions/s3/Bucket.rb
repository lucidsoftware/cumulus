require "conf/Configuration"
require "s3/S3"

module AwsExtensions
  module S3
    module Bucket
      # Public: Method that will request the location of the bucket. Used to monkey patch
      # Aws::S3::Types::Bucket
      def location
        location = Cumulus::S3::client.get_bucket_location({bucket: name}).location_constraint
        if location == ""
          Cumulus::Configuration.instance.region
        else
          location
        end
      end
    end
  end
end
