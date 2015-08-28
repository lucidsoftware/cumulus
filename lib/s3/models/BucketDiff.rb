require "common/models/Diff"
require "common/models/TagsDiff"
require "util/Colors"

module Cumulus
  module S3
    # Public: The types of changes that can be made to an S3 bucket
    module BucketChange
      include Common::DiffChange

      CORS = Common::DiffChange.next_change_id
      GRANTS = Common::DiffChange.next_change_id
      LIFECYCLE = Common::DiffChange.next_change_id
      LOGGING = Common::DiffChange.next_change_id
      NOTIFICATIONS = Common::DiffChange.next_change_id
      POLICY = Common::DiffChange.next_change_id
      REPLICATION = Common::DiffChange.next_change_id
      TAGS = Common::DiffChange.next_change_id
      VERSIONING = Common::DiffChange.next_change_id
      WEBSITE = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # S3 bucket configuration
    class BucketDiff < Common::Diff
      include BucketChange
      include Common::TagsDiff

      attr_accessor :grants
      attr_accessor :lifecycle
      attr_accessor :notifications
      attr_accessor :replication

      # Public: Static method that will create a diff representing changes in grants
      #
      # grants - the grant changes
      # local  - the local configuration
      #
      # Returns the diff
      def self.grant_changes(grants, local)
        diff = BucketDiff.new(GRANTS, nil, local)
        diff.grants = grants
        diff
      end

      # Public: Static method that will create a diff representing changes in
      # notifications.
      #
      # notifications - the notification changes
      # local         - the local configuration
      #
      # Returns the diff
      def self.notification_changes(notifications, local)
        diff = BucketDiff.new(NOTIFICATIONS, nil, local)
        diff.notifications = notifications
        diff
      end

      # Public: Static method that will create a diff representing changes in
      # lifecycle rules.
      #
      # lifecycle - the lifecycle changes
      # local     - the local configuration
      #
      # Returns the diff
      def self.lifecycle_changes(lifecycle, local)
        diff = BucketDiff.new(LIFECYCLE, nil, local)
        diff.lifecycle = lifecycle
        diff
      end

      # Public: Static method that will create a diff representing changes in
      # replication configuration.
      #
      # replication - the replication configuration
      # local       - the local configuration
      #
      # Returns the diff
      def self.replication_changes(replication, local)
        diff = BucketDiff.new(REPLICATION, nil, local)
        diff.replication = replication
        diff
      end

      def diff_string
        case @type
        when CORS
          [
            "CORS Rules:",
            removed_cors.map { |cors| Colors.removed("\t#{cors}") },
            added_cors.map { |cors| Colors.added("\t#{cors}") }
          ].flatten.join("\n")
        when GRANTS
          [
            "Grants:",
            grants.flat_map { |g| g.to_s.lines.map { |s| "\t#{s}" }.join },
          ].flatten.join("\n")
        when LIFECYCLE
          [
            "Lifecycle Rules:",
            lifecycle.flat_map { |n| n.to_s.lines.map { |s| "\t#{s}" }.join },
          ].flatten.join("\n")
        when LOGGING
          [
            "Logging Settings:",
            Colors.aws_changes("\tAWS\t- #{if @aws.logging.to_cumulus then @aws.logging.to_cumulus else "Not enabled" end}"),
            Colors.local_changes("\tLocal\t- #{if @local.logging then @local.logging else "Not enabled" end}")
          ].join("\n")
        when NOTIFICATIONS
          [
            "Notifications:",
            notifications.flat_map { |n| n.to_s.lines.map { |s| "\t#{s}" }.join },
          ].flatten.join("\n")
        when POLICY
          [
            "Bucket Policy:",
            Colors.aws_changes("\tAWS\t- #{@aws.policy.policy_string}"),
            Colors.local_changes("\tLocal\t- #{@local.policy}")
          ].join("\n")
        when REPLICATION
          [
            "Replication:",
            replication.flat_map { |r| r.to_s.lines.map { |s| "\t#{s}" }.join },
          ].flatten.join("\n")
        when TAGS
          tags_diff_string
        when VERSIONING
          "Versioning: AWS - #{Colors.aws_changes(@aws.versioning.enabled)}, Local - #{Colors.local_changes(@local.versioning)}"
        when WEBSITE
          [
            "S3 Website Settings:",
            Colors.aws_changes("\tAWS\t- #{if @aws.website.to_cumulus then @aws.website.to_cumulus else "Not enabled" end}"),
            Colors.local_changes("\tLocal\t- #{if @local.website then @local.website else "Not enabled" end}"),
          ].join("\n")
        end
      end

      def asset_type
        "Bucket"
      end

      def aws_name
        @aws.name
      end

      # Public: Get the CORS rules to remove.
      #
      # Returns an array of CORSRules
      def removed_cors
        @aws.cors.rules - (@local.cors || [])
      end

      # Public: Get the CORS rules to add.
      #
      # Returns an array of CORSRules.
      def added_cors
        (@local.cors || []) - @aws.cors.rules
      end

      private

      def aws_tags_list
        @aws.tagging.safe_tags
      end
    end
  end
end
