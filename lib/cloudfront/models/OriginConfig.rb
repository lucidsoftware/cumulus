require "conf/Configuration"
require "cloudfront/models/CustomHeaderConfig"
require "cloudfront/models/CustomHeaderDiff"
require "cloudfront/models/CustomOriginConfig"
require "cloudfront/models/OriginDiff"
require "cloudfront/models/OriginSslProtocols"
require "util/AwsUtil"

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
      attr_reader :custom_origin_headers

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
              json["custom-origin-config"]["protocol-policy"],
              json["custom-origin-config"]["origin-ssl-protocols"] && OriginSslProtocols.new(
                json["custom-origin-config"]["origin-ssl-protocols"]
              )
            )
          end
          @custom_headers = if json["custom-headers"].nil?
            []
          else
            json["custom-headers"].map do |name, value|
              CustomHeaderConfig.new(name, value)
            end
          end
          @name = @id
        end
      end

      def populate!(aws)
        @id = aws.id
        @domain_name = aws.domain_name
        @origin_path = aws.origin_path
        @s3_access_origin_identity = if aws.s3_origin_config then aws.s3_origin_config.origin_access_identity end
        @custom_origin_config = if aws.custom_origin_config
          CustomOriginConfig.new(
            aws.custom_origin_config.http_port,
            aws.custom_origin_config.https_port,
            aws.custom_origin_config.origin_protocol_policy,
            aws.custom_origin_config.origin_ssl_protocols && OriginSslProtocols.new(
              aws.custom_origin_config.origin_ssl_protocols.items
            )
          )
        end
        @custom_headers = (aws.custom_headers.items || []).map do |header|
          CustomHeaderConfig.new(header.header_name, header.header_value)
        end
        @name = @id
      end

      # Public: Get the config as a hash
      #
      # Returns the hash
      def to_local
        {
          "id" => @id,
          "domain-name" => @domain_name,
          "origin-path" => @origin_path,
          "s3-origin-access-identity" => @s3_access_origin_identity,
          "custom-origin-config" => if @custom_origin_config.nil? then nil else @custom_origin_config.to_local end,
          "custom-headers" => Hash[@custom_headers.map do |header|
              [header.name, header.value]
            end]
        }.reject { |k, v| v.nil? }
      end

      def to_aws
        {
          id: @id,
          domain_name: @domain_name,
          origin_path: @origin_path,
          s3_origin_config: if @s3_access_origin_identity.nil? then nil else
            {
              origin_access_identity: @s3_access_origin_identity
            }
          end,
          custom_origin_config: if @custom_origin_config.nil? then nil else
            {
              http_port: @custom_origin_config.http_port,
              https_port: @custom_origin_config.https_port,
              origin_protocol_policy: @custom_origin_config.protocol_policy,
              origin_ssl_protocols: if @custom_origin_config.origin_ssl_protocols
                {
                  quantity: @custom_origin_config.origin_ssl_protocols.quantity,
                  items: @custom_origin_config.origin_ssl_protocols.items,
                }
              end
            }
          end,
         custom_headers: AwsUtil.aws_array(@custom_headers.map(&:to_aws))
        }
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
          if @s3_access_origin_identity != aws.s3_origin_config.origin_access_identity
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
            diffs << OriginDiff.custom(custom_diffs, aws, self) if !custom_diffs.empty?
          end
        else
          custom_diffs = @custom_origin_config.diff(aws.custom_origin_config)
          diffs << OriginDiff.custom(custom_diffs, aws, self) if !custom_diffs.empty?
        end

        header_diffs = diff_custom_headers(aws.custom_headers.items)
        if !header_diffs.empty?
          diffs << OriginDiff.headers(header_diffs, self)
        end

        diffs.flatten
      end

      # Internal : Produce an array of difference between local and remove custom origin headers
      #
      # aws_headers - the custom origin headers
      #
      # Returns an array of CustomHeaderDiffs that were found
      def diff_custom_headers(aws_headers)
        diffs = []

        #map headers to their names
        aws = Hash[aws_headers.map { |o| [o.header_name, o] }]
        local = Hash[@custom_headers.map { |o| [o.name, o] }]

        # find headers not configured locally
        aws.each do |header_name, header|
          if !local.include?(header_name)
            diffs << CustomHeaderDiff.unmanaged(header)
          end
        end

        local.each do |header_name, header|
          if !aws.include?(header_name)
            diffs << CustomHeaderDiff.added(header)
          else
            diffs += header.diff(aws[header_name])
          end
        end

        diffs
      end

    end
  end
end
