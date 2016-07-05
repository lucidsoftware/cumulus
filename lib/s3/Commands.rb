module Cumulus
  module S3
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.manager
        require "s3/manager/Manager"
        Cumulus::S3::Manager.new
      end

      def self.banner_message
        [
          "s3: Manage S3 Buckets",
          "\tDiff and sync S3 bucket configuration with AWS.",
        ].join("\n")
      end

    end
  end
end
