module AwsExtensions
  module S3
    module BucketVersioning
      # Public: Return whether versioning is currently on. We need this method
      # because AWS returns nil when you've never versioned or the string
      # 'Suspended' if you had in the past, but have turned it off.
      #
      # Returns whether versioning is currently on
      def enabled
        !(status.nil? or status.downcase == "suspended")
      end
    end
  end
end
