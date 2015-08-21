require "conf/Configuration"
require "cloudfront/models/OriginDiff"
require "cloudfront/models/CustomOriginConfig"

require "json"

module Cumulus
  module CloudFront
    # Public: An object representing configuration for a origin
    class OriginConfig
      attr_reader :name
      attr_reader :id
      attr_reader :domain_name
      attr_reader :origin_path
      attr_reader :s3_access_origin_identity
      attr_reader :custom_origin_config


      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the origin
      def initialize(json = nil)
        if !json.nil?
          @id = json["id"]
          @domain_name = json["domain-name"]
          @origin_path = json["origin-path"]
          @s3_access_origin_identity = json["s3-origin-access-identity"]
          @custom_origin_config = if json["custom-origin-config"].nil?
            nil
          else
            CustomOriginConfig.new(
              json["custom-origin-config"]["http-port"],
              json["custom-origin-config"]["https-port"],
              json["custom-origin-config"]["protocol-policy"]
            )
          end
          @name = @id
        end
      end

      # Public: Get the config as a hash
      #
      # Returns the hash
      def to_hash
        {
          "id" => @id,
          "domain-name" => @domain_name,
          "origin-path" => @origin_path,
          "s3-origin-access-identity" => @s3_access_origin_identity,
          "custom-origin-config" => @custom_origin_config.to_hash
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the OriginDiffs that were found
      def diff(aws)
        diffs = []

        if @domain_name != aws.domain_name
          diffs << OriginDiff.new(OriginChange::DOMAIN, aws, self)
        end

        if @origin_path != aws.origin_path
          diffs << OriginDiff.new(OriginChange::PATH, aws, self)
        end

        # If s3 origin is defined here but not aws
        if !aws.s3_origin_config.nil?
          if @s3_access_origin_identity != aws.s3_origin_config.s3_access_origin_identity
            diffs << OriginDiff.new(OriginChange::S3, aws, self)
          end
        else
          if !@s3_access_origin_identity.nil?
            diffs << OriginDiff.new(OriginChange::S3, aws, self)
          end
        end

        if @custom_origin_config.nil?
          if !aws.custom_origin_config.nil?
            custom_diffs = CustomOriginConfig.new(nil, nil, nil).diff(aws.custom_origin_config)
            diffs << OriginDiff.custom(custom_diffs, self) if !custom_diffs.empty?
          end
        else
          custom_diffs = @custom_origin_config.diff(aws.custom_origin_config)
          diffs << OriginDiff.custom(custom_diffs, self) if !custom_diffs.empty?
        end

        diffs.flatten
      end

    end
  end
end
