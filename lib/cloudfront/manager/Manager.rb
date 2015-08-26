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

      def create(local)
        create_config = {
          distribution_config: {
            caller_reference: local.file_name,
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
        }

        local.id = @cloudfront.create_distribution(create_config).distribution.id

        # Save the updated local config with id
        File.open("#{Configuration.instance.cloudfront.distributions_directory}/#{local.file_name}.json", "w") { |f| f.write(local.pretty_json) }
        puts "Distribution #{local.file_name} created with id #{local.id}"

      rescue => e
        puts "Failed to create distribution #{local.file_name}\n#{e}"
      end

      def invalidate(invalidation_name)

        invalidation = Loader.invalidation(invalidation_name)

        # Use a combination of the current time and md5 of paths to prevent
        # identical invalidations from being ran too often
        time_throttle = (Time.now.to_i / 60 / 5)
        md5 = Digest::MD5.hexdigest(invalidation.paths.join)[0..5]

        @cloudfront.create_invalidation({
          distribution_id: invalidation.distribution_id,
          invalidation_batch: {
            paths: {
              quantity: invalidation.paths.size,
              items: if !invalidation.paths.empty? then invalidation.paths end
            },
            caller_reference: "#{invalidation_name}-#{md5}-#{time_throttle}"
          }
        })

      end

    end
  end
end
