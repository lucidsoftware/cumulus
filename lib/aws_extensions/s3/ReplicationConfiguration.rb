require "s3/models/ReplicationConfig"

module AwsExtensions
  module S3
    module ReplicationConfiguration
      # Public: Convert this Aws::S3::Types::ReplicationConfiguration into a
      # Cumulus::S3::ReplicationConfig
      #
      # Returns the ReplicationConfig
      def to_cumulus
        cumulus = Cumulus::S3::ReplicationConfig.new
        cumulus.populate!(self)

        if self.rules[0].status.downcase != "disabled"
          cumulus
        end
      rescue
        nil
      end
    end
  end
end
