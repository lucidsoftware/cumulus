require "common/manager/Manager"
require "conf/Configuration"
require "s3/loader/Loader"
require "s3/models/BucketConfig"
require "s3/models/BucketDiff"
require "s3/S3"
require "util/Colors"

require "aws-sdk"

module Cumulus
  module S3
    class Manager < Common::Manager
      def migrate
        buckets_dir = "#{@migration_root}/buckets"
        cors_dir = "#{@migration_root}/cors"
        policy_dir = "#{@migration_root}/policies"

        [@migration_root, buckets_dir, cors_dir, policy_dir].each do |dir|
          if !Dir.exists?(dir)
            Dir.mkdir(dir)
          end
        end

        cors = {}
        policies = {}

        aws_resources.each_value do |resource|
          puts "Processing #{resource.name}..."
          full_aws = S3.full_bucket(resource.name)
          config = BucketConfig.new(resource.name)
          new_policy_key, new_cors_key = config.populate!(full_aws, cors, policies)

          puts "Writing #{resource.name} configuration to file..."
          if new_policy_key
            File.open("#{policy_dir}/#{new_policy_key}.json", "w") { |f| f.write(policies[new_policy_key]) }
          end
          if new_cors_key
            File.open("#{cors_dir}/#{new_cors_key}.json", "w") { |f| f.write(cors[new_cors_key]) }
          end
          File.open("#{buckets_dir}/#{resource.name}.json", "w") { |f| f.write(config.pretty_json) }
        end
      end

      def resource_name
        "Bucket"
      end

      def local_resources
        Hash[Loader.buckets.map { |bucket| [bucket.name, bucket] }]
      end

      def aws_resources
        S3.buckets
      end

      def unmanaged_diff(aws)
        BucketDiff.unmanaged(aws)
      end

      def added_diff(local)
        BucketDiff.added(local)
      end

      def diff_resource(local, aws)
        if Configuration.instance.s3.print_progress
          puts "checking for differences in #{local.name}"
        end
        full_aws = S3.full_bucket(aws.name)
        local.diff(full_aws)
      end

      def create(local)
        S3.client(local.region).create_bucket({
          bucket: local.name,
          create_bucket_configuration: if local.region != "us-east-1" then {
            location_constraint: local.region
          } end
        })
        update_policy(local.region, local.name, local.policy)
        update_cors(local.region, local.name, local.cors)
        update_grants(local.region, local.name, local.grants)
        update_versioning(local.region, local.name, local.versioning)
        update_logging(local.region, local.name, local.logging)
        update_website(local.region, local.name, local.website)
        update_lifecycle(local.region, local.name, local.lifecycle)
        update_notifications(local.region, local.name, local.notifications)
        update_replication(local.region, local.name, local.replication)
        update_tags(local.region, local.name, local.tags)
      end

      def update(local, diffs)
        diffs.each do |diff|
          if diff.type == BucketChange::TAGS
            puts Colors.blue("\tupdating tags...")
            update_tags(diff.local.region, diff.local.name, diff.local.tags)
          elsif diff.type == BucketChange::POLICY
            puts Colors.blue("\tupdating policy...")
            update_policy(diff.local.region, diff.local.name, diff.local.policy)
          elsif diff.type == BucketChange::CORS
            puts Colors.blue("\tupdating CORS rules...")
            update_cors(diff.local.region, diff.local.name, diff.local.cors)
          elsif diff.type == BucketChange::WEBSITE
            puts Colors.blue("\tupdating S3 bucket website...")
            update_website(diff.local.region, diff.local.name, diff.local.website)
          elsif diff.type == BucketChange::LOGGING
            puts Colors.blue("\tupdating S3 bucket logging..")
            update_logging(diff.local.region, diff.local.name, diff.local.logging)
          elsif diff.type == BucketChange::VERSIONING
            puts Colors.blue("\tupdating versioning status...")
            update_versioning(diff.local.region, diff.local.name, diff.local.versioning)
          elsif diff.type == BucketChange::GRANTS
            puts Colors.blue("\tupdating grants...")
            update_grants(diff.local.region, diff.local.name, diff.local.grants)
          elsif diff.type == BucketChange::LIFECYCLE
            puts Colors.blue("\tupdating lifecycle...")
            update_lifecycle(diff.local.region, diff.local.name, diff.local.lifecycle)
          elsif diff.type == BucketChange::NOTIFICATIONS
            puts Colors.blue("\tupdating notifications...")
            update_notifications(diff.local.region, diff.local.name, diff.local.notifications)
          elsif diff.type == BucketChange::REPLICATION
            puts Colors.blue("\tupdating replication...")
            update_replication(diff.local.region, diff.local.name, diff.local.replication)
          end
        end
      end

      private

      # Internal: Update the tags for a bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # tags        - the tags that belong to the bucket
      def update_tags(region, bucket_name, tags)
        S3.client(region).put_bucket_tagging({
          bucket: bucket_name,
          tagging: {
            tag_set: tags.map { |k, v| { key: k, value: v } }
          }
        })
      end

      # Internal: Update the policy for a bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # policy      - the policy to apply to the bucket
      def update_policy(region, bucket_name, policy)
        if policy
          S3.client(region).put_bucket_policy({
            bucket: bucket_name,
            policy: policy
          })
        else
          S3.client(region).delete_bucket_policy({
            bucket: bucket_name
          })
        end
      end

      # Internal: Update the CORS rules for a bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # cors        - the cors rules for the bucket
      def update_cors(region, bucket_name, cors)
        if cors
          S3.client(region).put_bucket_cors({
            bucket: bucket_name,
            cors_configuration: {
              cors_rules: cors
            }
          })
        else
          S3.client(region).delete_bucket_cors({
            bucket: bucket_name
          })
        end
      end

      # Internal: Update the bucket website configuration for the bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # website     - the website configuration for the bucket
      def update_website(region, bucket_name, website)
        if website
          S3.client(region).put_bucket_website({
            bucket: bucket_name,
            website_configuration: website.to_aws
          })
        else
          S3.client(region).delete_bucket_website({ bucket: bucket_name })
        end
      end

      # Internal: Update the bucket logging configuration for the bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # logging     - the logging configuration for the bucket
      def update_logging(region, bucket_name, logging)
        S3.client(region).put_bucket_logging({
          bucket: bucket_name,
          bucket_logging_status: {
            logging_enabled: (logging.to_aws rescue nil)
          }
        })
      end

      # Internal: Update the bucket versioning for the bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # enabled     - whether versioning should be enabled or not
      def update_versioning(region, bucket_name, enabled)
        S3.client(region).put_bucket_versioning({
          bucket: bucket_name,
          versioning_configuration: {
            status: if enabled then "Enabled" else "Suspended" end
          }
        })
      end

      # Internal: Update the permission grants for the bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # grants      - the grants for the bucket
      def update_grants(region, bucket_name, grants)
        S3.client(region).put_bucket_acl({
          bucket: bucket_name,
          access_control_policy: {
            grants: grants.values.map(&:to_aws).flatten,
            owner: S3.full_bucket(bucket_name).acl.owner
          }
        })
      end

      # Internal: Update the lifecycle rules for the bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # lifecycle   - the lifecycle rules for the bucket
      def update_lifecycle(region, bucket_name, lifecycle)
        if lifecycle.empty?
          S3.client(region).delete_bucket_lifecycle({
            bucket: bucket_name
          })
        else
          S3.client(region).put_bucket_lifecycle({
            bucket: bucket_name,
            lifecycle_configuration: {
              rules: lifecycle.values.map(&:to_aws)
            }
          })
        end
      end

      # Internal: Update the notification rules for the bucket.
      #
      # bucket_name   - the name of the bucket
      # notifications - the notification rules for the bucket
      def update_notifications(region, bucket_name, notifications)
        S3.client(region).put_bucket_notification_configuration({
          bucket: bucket_name,
          notification_configuration: {
            topic_configurations: notifications.values.select { |n| n.type == "sns" }.map(&:to_aws),
            queue_configurations: notifications.values.select { |n| n.type == "sqs" }.map(&:to_aws),
            lambda_function_configurations: notifications.values.select { |n| n.type == "lambda" }.map(&:to_aws)
          }
        })
      end

      # Internal: Update the replication rules for the bucket.
      #
      # region - the region of the bucket
      # bucket_name - the name of the bucket
      # replication - the replication rules for the bucket
      def update_replication(region, bucket_name, replication)
        if replication
          S3.client(region).put_bucket_replication({
            bucket: bucket_name,
            replication_configuration: replication.to_aws
          })
        else
          S3.client(region).delete_bucket_replication({
            bucket: bucket_name
          })
        end
      end
    end
  end
end
