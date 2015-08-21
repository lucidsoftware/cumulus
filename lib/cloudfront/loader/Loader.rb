require "common/BaseLoader"
require "conf/Configuration"
require "cloudfront/models/DistributionConfig"

# Public: Load CloudFront assets
module Cumulus
  module CloudFront
    module Loader
      include Common::BaseLoader

      @@distributions_dir = Configuration.instance.cloudfront.distributions_directory

      # Public: Load all the distribution configurations as DistributionConfig objects
      #
      # Returns an array of DistributionConfig
      def self.distributions
        Common::BaseLoader::resources(@@distributions_dir, &DistributionConfig.method(:new))
      end

    end
  end
end
