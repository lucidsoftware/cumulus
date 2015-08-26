require "s3/models/WebsiteConfig"

module AwsExtensions
  module S3
    module BucketWebsite
      # Public: Convert this Aws::S3::BucketWebsite into a Cumulus::S3:WebsiteConfig
      #
      # Returns a WebsiteConfig
      def to_cumulus
        cumulus = Cumulus::S3::WebsiteConfig.new
        cumulus.populate!(self)
        cumulus
      end

      # Public: Get the index_document if it is present, or nil if it is not
      #
      # Returns the value
      def safe_index
        index_document.key
      rescue Aws::S3::Errors::NoSuchWebsiteConfiguration
        nil
      end

      # Public: Get the error_document if it is present, or nil if it is not
      #
      # Returns the value
      def safe_error
        error_document.key
      rescue Aws::S3::Errors::NoSuchWebsiteConfiguration
        nil
      end

      # Public: Get the redirection if it is present, or nil if it is not
      #
      # Returns the value
      def safe_redirection
        "#{redirect_all_requests_to.protocol}://#{redirect_all_requests_to.host_name}"
      rescue Aws::S3::Errors::NoSuchWebsiteConfiguration
        nil
      end
    end
  end
end
