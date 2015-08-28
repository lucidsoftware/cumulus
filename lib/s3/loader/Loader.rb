require "common/BaseLoader"
require "conf/Configuration"
require "s3/models/BucketConfig"

require "aws-sdk"

module Cumulus
  module S3
    module Loader
      include Common::BaseLoader

      @@buckets_dir = Configuration.instance.s3.buckets_directory
      @@cors_dir = Configuration.instance.s3.cors_directory
      @@policies_dir = Configuration.instance.s3.policies_directory

      # Public: Load all the bucket configurations a BucketConfig objects
      #
      # Returns an array of BucketConfigs
      def self.buckets
        Common::BaseLoader.resources(@@buckets_dir, &BucketConfig.method(:new))
      end

      # Public: Load a specific CORS policy by name, applying any variables.
      #
      # name - the name of the file to load
      # vars - the variables to apply to the template
      #
      # Returns the CORS policy as a string
      def self.cors_policy(name, vars)
        Common::BaseLoader.template(
          name,
          @@cors_dir,
          vars,
          &proc do |n, json| json.map do |rule|
              Aws::S3::Types::CORSRule.new({
                allowed_headers: rule.fetch("headers"),
                allowed_methods: rule.fetch("methods"),
                allowed_origins: rule.fetch("origins"),
                expose_headers: rule.fetch("exposed-headers"),
                max_age_seconds: rule.fetch("max-age-seconds")
              })
            end
          end
        )
      rescue KeyError
        puts "CORS configuration #{name} does not contain all required keys."
        exit
      end

      # Public: Load a specific bucket policy by name, applying any variables
      #
      # name - the name of the file to load
      # vars - the variables to apply to the template
      #
      # Returns the bucket policy as a string
      def self.bucket_policy(name, vars)
        Common::BaseLoader.template(
          name,
          @@policies_dir,
          vars,
          &proc { |n, json| json.to_json }
        )
      end
    end
  end
end
