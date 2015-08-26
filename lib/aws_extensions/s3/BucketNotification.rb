require "s3/models/NotificationConfig"

module AwsExtensions
  module S3
    module BucketNotification
      # Public: Convert this Aws::S3::BucketNotification into an array of
      # Cumulus::S3::NotificationConfig
      #
      # Returns the array of NotificationConfigs
      def to_cumulus
        Hash[(
          lambda_function_configurations +
          queue_configurations +
          topic_configurations
        ).map do |configuration|
          cumulus = Cumulus::S3::NotificationConfig.new
          cumulus.populate!(configuration)
          cumulus
        end.map { |configuration| [configuration.name, configuration] }]
      end
    end
  end
end
