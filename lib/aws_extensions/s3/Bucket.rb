require "conf/Configuration"
require "s3/S3"

require "aws-sdk-s3"

module AwsExtensions
  module S3
    module Types
      module Bucket
        # Public: Method that will request the location of the bucket. Used to monkey patch
        # Aws::S3::Types::Bucket
        def location
          location = Cumulus::S3::client.get_bucket_location({bucket: name}).location_constraint
          if location == ""
            Cumulus::Configuration.instance.client[:region]
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

      def default_encryption
        conf = Cumulus::S3::client(location).get_bucket_encryption({bucket: name}).server_side_encryption_configuration
        conf.rules.find do |r|
          sse = r.apply_server_side_encryption_by_default
          sse and break sse
        end
      rescue Aws::S3::Errors::ServerSideEncryptionConfigurationNotFoundError
        nil
      end
    end
  end
end
