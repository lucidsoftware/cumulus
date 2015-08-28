require "s3/models/GrantConfig"

module AwsExtensions
  module S3
    module BucketAcl
      # Public: Turn the grants in the Aws::S3::BucketAcl into an array of
      # Cumulus::S3::Grant so we can use them.
      #
      # Returns an array of Grants
      def to_cumulus
        grants_hash = {}

        grants.each do |grant|
          cumulus = Cumulus::S3::GrantConfig.new
          cumulus.populate!(grant)

          if grants_hash.include? cumulus.name
            grants_hash[cumulus.name].add_permissions!(cumulus.permissions)
          else
            grants_hash[cumulus.name] = cumulus
          end
        end

        grants_hash
      end
    end
  end
end
