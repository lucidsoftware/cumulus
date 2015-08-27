require "s3/models/LoggingConfig"

module AwsExtensions
  module S3
    module BucketLogging
      # Public: Convert this Aws::S3::BucketLogging into a Cumulus::S3::LoggingConfig
      #
      # Returns a LoggingConfig
      def to_cumulus
        if logging_enabled
          cumulus = Cumulus::S3::LoggingConfig.new
          cumulus.populate!(self)
          cumulus
        end
      end
    end
  end
end
