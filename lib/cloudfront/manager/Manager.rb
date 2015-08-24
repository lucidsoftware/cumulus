require "common/manager/Manager"
require "conf/Configuration"
require "cloudfront/CloudFront"
require "cloudfront/loader/Loader"
require "cloudfront/models/DistributionDiff"
require "util/Colors"

require "aws-sdk"

module Cumulus
  module CloudFront
    class Manager < Common::Manager
      def initialize
        super()
        @create_asset = false
        @cloudfront = Aws::CloudFront::Client.new(region: Configuration.instance.region)
      end

      def resource_name
        "CloudFront Distribution"
      end

      def local_resources
        @local_resources ||= Hash[Loader.distributions.map { |local| [local.id, local] }]
      end

      def aws_resources
        @aws_resources ||= CloudFront::id_distributions
      end

      def full_distribution(distribution_id)
        @full_aws_configs ||= Hash.new

        @full_aws_configs[distribution_id] ||= CloudFront::load_distribution_config(distribution_id)
      end

      def unmanaged_diff(aws)
        DistributionDiff.unmanaged(aws)
      end

      def added_diff(local)
        DistributionDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(full_distribution(aws.id).distribution_config)
      end

      def update(local, diffs)
        if !diffs.empty?
          full_aws_response = full_distribution(local.id)

          aws_config = full_aws_response.distribution_config

          updated_config = {
            aliases: {
              quantity: local.aliases.size,
              items: if local.aliases.empty? then nil else local.aliases end
            },
            origins: {
              quantity: local.origins.size,
              items: if local.origins.empty? then nil else local.origins.map(&:to_aws) end
            },
            default_cache_behavior: local.default_cache_behavior.to_aws,
            cache_behaviors: {
              quantity: local.cache_behaviors.size,
              items: if local.cache_behaviors.empty? then nil else local.cache_behaviors.map(&:to_aws) end
            },
            comment: local.comment,
            enabled: local.enabled
          }

          update_params = {
            id: local.id,
            if_match: full_aws_response.etag,
            distribution_config: aws_config.to_h.merge(updated_config)
          }

          @cloudfront.update_distribution(update_params)
        end

      end

    end
  end
end
