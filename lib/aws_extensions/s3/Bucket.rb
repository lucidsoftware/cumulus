require "conf/Configuration"
require "s3/S3"

module AwsExtensions
  module S3
    module Types
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

    module Bucket
      # Public: Method used to extend the Bucket class so that it will return
      # replication rules.
      #
      # Returns the associated Aws::S3::Types::ReplicationConfiguration
      def replication
        Cumulus::S3::client(location).get_bucket_replication({bucket: name}).replication_configuration
      rescue Aws::S3::Errors::ReplicationConfigurationNotFoundError
        nil
      end
    end
  end
end
