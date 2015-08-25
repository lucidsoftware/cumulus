require "common/BaseLoader"
require "conf/Configuration"
require "cloudfront/models/DistributionConfig"
require "cloudfront/models/InvalidationConfig"

# Public: Load CloudFront assets
module Cumulus
  module CloudFront
    module Loader
      include Common::BaseLoader

      @@distributions_dir = Configuration.instance.cloudfront.distributions_directory
      @@invalidations_dir = Configuration.instance.cloudfront.invalidations_directory

      # Public: Load all the distribution configurations as DistributionConfig objects
      #
      # Returns an array of DistributionConfig
      def self.distributions
        Common::BaseLoader::resources(@@distributions_dir, &DistributionConfig.method(:new))
      end

      # Public: Load an invalidation configuration as an InvalidationConfig object
      #
      # Returns a single InvalidationConfig
      def self.invalidation(invalidation_name)
        Common::BaseLoader::resource(invalidation_name, @@invalidations_dir, &InvalidationConfig.method(:new))
      end

    end
  end
end
