require "aws_extensions/s3/Bucket"
require "aws_extensions/s3/BucketAcl"
require "aws_extensions/s3/BucketCors"
require "aws_extensions/s3/BucketLifecycle"
require "aws_extensions/s3/BucketLogging"
require "aws_extensions/s3/BucketNotification"
require "aws_extensions/s3/BucketPolicy"
require "aws_extensions/s3/BucketTagging"
require "aws_extensions/s3/BucketVersioning"
require "aws_extensions/s3/BucketWebsite"
require "aws_extensions/s3/CORSRule"
require "aws_extensions/s3/ReplicationConfiguration"
require "aws_extensions/s3/ServerSideEncryptionByDefault"
require "s3/loader/Loader"
require "s3/models/BucketDiff"
require "s3/models/DefaultEncryptionConfig"
require "s3/models/DefaultEncryptionDiff"
require "s3/models/GrantConfig"
require "s3/models/GrantDiff"
require "s3/models/LifecycleConfig"
require "s3/models/LoggingConfig"
require "s3/models/NotificationConfig"
require "s3/models/ReplicationConfig"
require "s3/models/ReplicationDiff"
require "s3/models/WebsiteConfig"

require "json"
require "aws-sdk-s3"

module Cumulus
  module S3
    # Monkey patch the bucket so that it can get the bucket's replication configuration
    Aws::S3::Bucket.send(:include, AwsExtensions::S3::Bucket)
    # Also monkey patch buckets so they can get their location
    Aws::S3::Bucket.send(:include, AwsExtensions::S3::Types::Bucket)
    # Monkey patch BucketPolicy so you can get the policy without an exception
    Aws::S3::BucketPolicy.send(:include, AwsExtensions::S3::BucketPolicy)
    # Monkey patch BucketCors for the same reason
    Aws::S3::BucketCors.send(:include, AwsExtensions::S3::BucketCors)
    # Same for BucketTagging
    Aws::S3::BucketTagging.send(:include, AwsExtensions::S3::BucketTagging)
    # Monkey patch CORSRule to provide a decent to string
    Aws::S3::Types::CORSRule.send(:include, AwsExtensions::S3::CORSRule)
    # Monkey patch BucketAcl to provide a way to get grants in Cumulus format
    Aws::S3::BucketAcl.send(:include, AwsExtensions::S3::BucketAcl)
    # Monkey patch BucketWebsite to convert BucketWebsite to Cumulus format
    Aws::S3::BucketWebsite.send(:include, AwsExtensions::S3::BucketWebsite)
    # Monkey patch BucketLogging to convert BucketLogging to Cumulus format
    Aws::S3::BucketLogging.send(:include, AwsExtensions::S3::BucketLogging)
    # Make it so BucketVersioning has a versioning method that matches our versioning method
    Aws::S3::BucketVersioning.send(:include, AwsExtensions::S3::BucketVersioning)
    # Monkey patch BucketNotification to return an array of EventConfigs
    Aws::S3::BucketNotification.send(:include, AwsExtensions::S3::BucketNotification)
    # Monkey patch BucketLifecycle to return an array of LifecycleConfigs
    Aws::S3::BucketLifecycle.send(:include, AwsExtensions::S3::BucketLifecycle)
    # Monkey patch ReplicationConfiguration to convert to Cumulus format
    Aws::S3::Types::ReplicationConfiguration.send(:include, AwsExtensions::S3::ReplicationConfiguration)
    # Monkey patch ServerSideEncryptionByDefault to convert to Cumulus format
    Aws::S3::Types::ServerSideEncryptionByDefault.send(:include, AwsExtensions::S3::ServerSideEncryptionByDefault)

    # Public: An object representing configuration for an S3 bucket
    class BucketConfig
      attr_reader :cors
      attr_reader :grants
      attr_reader :lifecycle
      attr_reader :logging
      attr_reader :name
      attr_reader :notifications
      attr_reader :policy
      attr_reader :region
      attr_reader :replication
      attr_reader :tags
      attr_reader :versioning
      attr_reader :website
      attr_reader :default_encryption

      # Public: Constructor
      #
      # name - the name of the bucket
      # json - a hash containing the JSON configuration for the bucket
      def initialize(name, json = nil)
        @name = name
        if json
          @region = json["region"]
          @tags = json["tags"] || {}
          if json["permissions"]["cors"]
            @cors = Loader.cors_policy(
              json["permissions"]["cors"]["template"],
              json["permissions"]["cors"]["vars"] || {}
            )
          end
          if json["permissions"]["policy"]
            @policy = Loader.bucket_policy(
              json["permissions"]["policy"]["template"],
              json["permissions"]["policy"]["vars"] || {}
            )
          end
          if json["permissions"]["grants"]
            @grants = Hash[json["permissions"]["grants"].map do |g|
              [g["name"], GrantConfig.new(g)]
            end]
          end
          if json["default_encryption"]
            @default_encryption = DefaultEncryptionConfig.new(json["default_encryption"])
          end
          @website = if json["website"] then WebsiteConfig.new(json["website"]) end
          @logging = if json["logging"] then LoggingConfig.new(json["logging"]) end
          @notifications = Hash[(json["notifications"] || []).map { |n| [n["name"], NotificationConfig.new(n)] }]
          @lifecycle = Hash[(json["lifecycle"] || []).map { |l| [l["name"], LifecycleConfig.new(l)] }]
          @versioning = json["versioning"] || false
          @replication = if json["replication"] then ReplicationConfig.new(json["replication"]) end
        end
      end

      # Public: Populate this BucketConfig from the values in an AWS bucket.
      #
      # aws      - the aws resource
      # cors     - a hash of the names of cors policies to the string value of those policies
      # policies - a hash of the names of policies to the string value of those policies
      #
      # Returns the key names of the new policy or cors policy so they can be written
      # to file immediately
      def populate!(aws, cors, policies)
        @region = aws.location
        @grants = aws.acl.to_cumulus
        @website = aws.website.to_cumulus
        @logging = aws.logging.to_cumulus
        @notifications = aws.notification.to_cumulus
        @lifecycle = aws.lifecycle.to_cumulus
        @versioning = aws.versioning.enabled
        @replication = aws.replication.to_cumulus rescue nil
        @tags = Hash[aws.tagging.safe_tags.map { |t| [t.key, t.value] }]
        default_encryption = aws.default_encryption
        if default_encryption
          @default_encryption = default_encryption.to_cumulus
        end

        policy = aws.policy.policy_string
        if policy and policy != ""
          policy = JSON.pretty_generate(JSON.parse(policy))
          if policies.has_value? policy
            @policy_name = policies.key(policy)
          else
            @policy_name = "#{@name}-policy"
            policies[@policy_name] = policy
            @new_policy_key = @policy_name
          end
        end

        cors_string = JSON.pretty_generate(aws.cors.rules.map(&:to_h))
        if cors_string and !aws.cors.rules.empty?
          if cors.has_value? cors_string
            @cors_name = cors.key(cors_string)
          else
            @cors_name = "#{@name}-cors"
            cors[@cors_name] = cors_string
            @new_cors_key = @cors_name
          end
        end

        return @new_policy_key, @new_cors_key
      end

      # Public: Produce a pretty JSON version of this BucketConfig.
      #
      # Returns the pretty JSON string.
      def pretty_json
        JSON.pretty_generate({
          region: @region,
          permissions: {
            policy: if @policy_name then {
              template: @policy_name,
            } end,
            cors: if @cors_name then {
              template: @cors_name,
            } end,
            grants: @grants.values.map(&:to_h)
          }.reject { |k, v| v.nil? },
          website: if @website then @website.to_h end,
          logging: if @logging then @logging.to_h end,
          notifications: if !@notifications.empty? then @notifications.values.map(&:to_h) end,
          lifecycle: if !@lifecycle.empty? then @lifecycle.values.map(&:to_h) end,
          versioning: @versioning,
          replication: if @replication then @replication.to_h end,
          default_encryption: if @default_encryption then @default_encryption end,
          tags: @tags,
        }.reject { |k, v| v.nil? })
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the BucketDiffs that were found
      def diff(aws)
        diffs = []

        if @tags != Hash[aws.tagging.safe_tags.map { |t| [t.key, t.value] }]
          diffs << BucketDiff.new(BucketChange::TAGS, aws, self)
        end
        if @policy != aws.policy.policy_string and !(@policy.nil? and aws.policy.policy_string == "")
          diffs << BucketDiff.new(BucketChange::POLICY, aws, self)
        end
        if @cors != aws.cors.rules and !(@cors.nil? and aws.cors.rules == [])
          diffs << BucketDiff.new(BucketChange::CORS, aws, self)
        end
        if @website != aws.website.to_cumulus
          diffs << BucketDiff.new(BucketChange::WEBSITE, aws, self)
        end
        if @logging != aws.logging.to_cumulus
          diffs << BucketDiff.new(BucketChange::LOGGING, aws, self)
        end
        if @versioning != aws.versioning.enabled
          diffs << BucketDiff.new(BucketChange::VERSIONING, aws, self)
        end

        grants_diffs = diff_grants(@grants, aws.acl.to_cumulus)
        if !grants_diffs.empty?
          diffs << BucketDiff.grant_changes(grants_diffs, self)
        end

        notification_diffs = diff_notifications(@notifications, aws.notification.to_cumulus)
        if !notification_diffs.empty?
          diffs << BucketDiff.notification_changes(notification_diffs, self)
        end

        lifecycle_diffs = diff_lifecycle(@lifecycle, aws.lifecycle.to_cumulus)
        if !lifecycle_diffs.empty?
          diffs << BucketDiff.lifecycle_changes(lifecycle_diffs, self)
        end

        aws_replication = aws.replication
        if aws_replication then aws_replication = aws_replication.to_cumulus end
        replication_diffs = diff_replication(@replication, aws_replication)
        if !replication_diffs.empty?
          diffs << BucketDiff.replication_changes(replication_diffs, self)
        end

        aws_default_encryption = aws.default_encryption
        if aws_default_encryption then aws_default_encryption = aws_default_encryption.to_cumulus end
        default_encryption_diffs = diff_encryption(@default_encryption, aws_default_encryption)
        if !default_encryption_diffs.empty?
          diffs << BucketDiff.default_encryption_changes(default_encryption_diffs, self)
        end

        diffs
      end

      private

      # Internal: Determine changes in grants.
      #
      # local - the grants defined locally (hash from name to config)
      # aws   - the grants defined in aws (hash from name to config)
      #
      # Returns an array of GrantDiffs represeting the differences between local
      # AWS configuration
      def diff_grants(local, aws)
        diff_configs(local, aws, {
          unmanaged: GrantDiff.method(:unmanaged),
          added: GrantDiff.method(:added)
        })
      end

      # Internal: Determine changes in notifications.
      #
      # local - the notifications defined locally (hash from name to config)
      # aws   - the notifications defined in aws (hash from name to config)
      #
      # Returns an array of NotificationDiffs representing the differences between
      # local and AWS configuration
      def diff_notifications(local, aws)
        diff_configs(local, aws, {
          unmanaged: NotificationDiff.method(:unmanaged),
          added: NotificationDiff.method(:added)
        })
      end

      # Internal: Determine changes in lifecycle rules.
      #
      # local - the lifecycle rules defined locally (hash from name to config)
      # aws   - the lifecycle rules defined in aws (hash from name to config)
      #
      # Returns an array of LifecycleDiffs representing the differences between
      # local and AWS configuration.
      def diff_lifecycle(local, aws)
        diff_configs(local, aws, {
          unmanaged: LifecycleDiff.method(:unmanaged),
          added: LifecycleDiff.method(:added)
        })
      end

      # Internal: Determine changes in replication.
      #
      # local - the local replication configuration
      # aws   - the aws replication configuration
      #
      # Returns an array of ReplicationDiffs representing the differences between
      # local and AWS configuration.
      def diff_replication(local, aws)
        diffs = []

        if local and aws
          diffs << local.diff(aws)
        elsif local
          diffs << ReplicationDiff.added(local)
        elsif aws
          diffs << ReplicationDiff.unmanaged(local)
        end

        diffs.flatten
      end

      # Internal: Determine changes in default encryption.
      #
      # local - the local default encryption configuration
      # aws   - the aws default encryption configuration
      #
      # Returns an array of DefaultEncryptionDiffs representing the differences between
      # local and AWS configuration.
      def diff_encryption(local, aws)
        diffs = []
        if local and aws
          diffs << local.diff(aws)
        elsif local
          diffs << DefaultEncryptionDiff.added(local)
        elsif aws
          diffs << DefaultEncryptionDiff.unmanaged(aws)
        end

        diffs.flatten
      end

      # Internal: Determine changes in sub configurations.
      #
      # local       - the local configurations (hash from name to config)
      # aws         - the aws configurations (hash from name to config)
      # options     - a hash that contains the following operations to run
      #   unmanaged - a function that creates the unmanaged diff
      #   added     - a function that creates the added diff
      #
      # Returns an array of diffs representing the differences between local
      # and AWS configuration
      def diff_configs(local, aws, options)
        diffs = []

        diffs << aws.reject { |k, v| local.include?(k) }.map { |k, v| options[:unmanaged].call(v) }
        local.each do |k, v|
          if aws.include?(k)
            if v != aws[k]
              diffs << v.diff(aws[k])
            end
          else
            diffs << options[:added].call(v)
          end
        end

        diffs.flatten
      end
    end
  end
end
