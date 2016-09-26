require "common/models/Diff"
require "util/Colors"

module Cumulus
  module CloudFront

  	# Public: The types of changes that can be made to zones
    module OriginChange
      include Common::DiffChange

      DOMAIN = Common::DiffChange::next_change_id
      PATH = Common::DiffChange::next_change_id
      S3 = Common::DiffChange::next_change_id
      CUSTOM = Common::DiffChange::next_change_id
      HEADERS = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of zones.
    class OriginDiff < Common::Diff
      include OriginChange

      attr_accessor :custom_changes
      attr_accessor :changed_headers

      # Public: Static method that produces a diff representing changes in custom origin
      #
      # changed_origins - the CustomOriginDiffs
      # local           - the local configuration for the zone
      #
      # Returns the diff
      def self.custom(changes, aws, local)
        diff = OriginDiff.new(CUSTOM, aws, local)
        diff.custom_changes = changes
        diff
      end

      def self.headers(changes, local)
        diff = OriginDiff.new(HEADERS, nil, local)
        diff.changed_headers = changes
        diff
      end

      def diff_string
        case @type
        when DOMAIN
          [
            "domain:",
            Colors.aws_changes("\tAWS - #{@aws.domain_name}"),
            Colors.local_changes("\tLocal - #{@local.domain_name}"),
          ].join("\n")
        when PATH
          [
            "path:",
            Colors.aws_changes("\tAWS - #{@aws.origin_path}"),
            Colors.local_changes("\tLocal - #{@local.origin_path}"),
          ].join("\n")
        when S3
          aws_value = (@aws.s3_origin_config.origin_access_identity rescue nil)
          [
            "s3 origin access identity:",
            Colors.aws_changes("\tAWS - #{aws_value}"),
            Colors.local_changes("\tLocal - #{@local.s3_access_origin_identity}"),
          ].join("\n")
        when CUSTOM
          [
            "custom origin config:",
            (@custom_changes.flat_map do |c|
              c.to_s.lines.map { |l| "\t#{l.chomp}"}
            end).join("\n"),
          ].join("\n")
        when HEADERS
          [
            "custom headers:",
            @changed_headers.map do |h|
              if h.type == ADD or h.type == UNMANAGED
                h.to_s.lines.map{ |l| "\t#{l}".chomp("\n") }
              else
                [
                  "\t#{o.local_name}",
                  h.to_s.lines.map { |l| "\t\t#{l}".chomp("\n")}
                ]
              end
            end
          ].flatten.join("\n")
        end
      end

      def asset_type
        if (!@local.nil? and @local.s3_access_origin_identity.nil?) or (!@aws.nil? and @aws.s3_origin_config.nil?)
          "Custom Origin"
        else
          "S3 Origin"
        end
      end

      def local_name
        @local.id
      end

      def aws_name
        @aws.id
      end

    end

  end
end
