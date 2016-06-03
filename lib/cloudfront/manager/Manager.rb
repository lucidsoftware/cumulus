require "common/manager/Manager"
require "conf/Configuration"
require "cloudfront/CloudFront"
require "cloudfront/loader/Loader"
require "cloudfront/models/DistributionDiff"
require "util/Colors"
require "util/StatusCodes"

require "aws-sdk"

module Cumulus
  module CloudFront
    class Manager < Common::Manager
      def initialize
        super()
        @cloudfront = Aws::CloudFront::Client.new(Configuration.instance.client)
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

      # Migrate AWS CloudFront distributions to local config
      def migrate
        distributions_dir = "#{@migration_root}/distributions"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(distributions_dir)
          Dir.mkdir(distributions_dir)
        end

        aws_resources.each_key do |dist_id|
          puts "Processing #{dist_id}..."
          full_config = full_distribution(dist_id).distribution_config

          config = DistributionConfig.new(dist_id)
          config.populate!(dist_id, full_config)

          puts "Writing #{dist_id} configuration to file"
          File.open("#{distributions_dir}/#{dist_id}.json", "w") { |f| f.write(config.pretty_json) }
        end
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

          begin
            @cloudfront.update_distribution(update_params)
          rescue Aws::CloudFront::Errors::InvalidArgument => e
            if e.message =~ /OriginSslProtocols is required/
              puts Colors.red("Distribution #{local.name} must specify $.custom-origin-config.origin-ssl-protocols when \"protocol-policy\" is \"https-only\". Distribution not updated")
              StatusCodes.set_status(StatusCodes::EXCEPTION)
            end
          end
        end

      end

      def create(local)
        create_config = {
          distribution_config: {
            caller_reference: local.name,
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
        File.open("#{Configuration.instance.cloudfront.distributions_directory}/#{local.name}.json", "w") { |f| f.write(local.pretty_json) }
        puts "Distribution #{local.name} created with id #{local.id}"

      rescue Aws::CloudFront::Errors::InvalidArgument => e
        if e.message =~ /OriginSslProtocols is required/
          puts Colors.red("Distribution #{local.name} must specify $.custom-origin-config.origin-ssl-protocols when \"protocol-policy\" is \"https-only\". Distribution not created")
          StatusCodes.set_status(StatusCodes::EXCEPTION)
        end
      rescue => e
        puts "Failed to create distribution #{local.name}\n#{e}"
      end

      def invalidations
        @invalidations ||= Hash[Loader.invalidations.map { |local| [local.name, local] }]
      end

      def list_invalidations
        puts invalidations.keys.join(" ")
      end

      def invalidate(invalidation_name)

        invalidation = invalidations[invalidation_name]

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
