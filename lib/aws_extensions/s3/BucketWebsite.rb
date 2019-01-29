require "s3/models/WebsiteConfig"

require "aws-sdk-s3"

module AwsExtensions
  module S3
    module BucketWebsite
      # Public: Convert this Aws::S3::BucketWebsite into a Cumulus::S3:WebsiteConfig
      #
      # Returns a WebsiteConfig
      def to_cumulus
        if safe_index or safe_redirection
          cumulus = Cumulus::S3::WebsiteConfig.new
          cumulus.populate!(self)
          cumulus
        end
      end

      # Public: Get the index_document if it is present, or nil if it is not
      #
      # Returns the value
      def safe_index
        index_document.suffix
      rescue Aws::S3::Errors::NoSuchWebsiteConfiguration, NoMethodError
        nil
      end

      # Public: Get the error_document if it is present, or nil if it is not
      #
      # Returns the value
      def safe_error
        error_document.key
      rescue Aws::S3::Errors::NoSuchWebsiteConfiguration, NoMethodError
        nil
      end

      # Public: Get the redirection if it is present, or nil if it is not
      #
      # Returns the value
      def safe_redirection
        if redirect_all_requests_to.protocol
          "#{redirect_all_requests_to.protocol}://#{redirect_all_requests_to.host_name}"
        else
          redirect_all_requests_to.host_name
        end
      rescue Aws::S3::Errors::NoSuchWebsiteConfiguration, NoMethodError
        nil
      end
    end
  end
end
