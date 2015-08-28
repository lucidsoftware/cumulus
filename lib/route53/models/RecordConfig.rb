require "aws_extensions/route53/AliasTarget"
require "aws_extensions/s3/Bucket"
require "cloudfront/CloudFront"
require "elb/ELB"
require "route53/models/AliasTarget"
require "route53/models/RecordDiff"
require "s3/S3"

require "aws-sdk"

module Cumulus
  module Route53
    # Monkey patch AliasTarget so we can call a method that will compare ELB DNS names correctly
    Aws::Route53::Types::AliasTarget.send(:include, AwsExtensions::Route53::AliasTarget)
    # Monkey patch Bucket so we can get the location of the bucket
    Aws::S3::Types::Bucket.send(:include, AwsExtensions::S3::Types::Bucket)

    # Public: An object representing configurationf for a single record in a zone
    class RecordConfig

      attr_reader :alias_target
      attr_reader :name
      attr_reader :ttl
      attr_reader :type
      attr_reader :value

      # Public: Constructor.
      #
      # json    - a hash containing the JSON configuration for the record
      # domain  - the domain of the zone this record belongs to
      # zone_id - the id of the zone this record belongs to
      def initialize(json = nil, domain = nil, zone_id = nil)
        if !json.nil?
          @name = if json["name"] == "" then domain else "#{json["name"].chomp(".")}.#{domain}".chomp(".") end
          @ttl = json["ttl"]
          @type = json["type"]

          if !json["value"].nil?
            @value = json["value"]

            # TXT and SPF records have each value wrapped in quotes
            if @type == "TXT" or @type == "SPF"
              @value = @value.map { |v| "\"#{v}\"" }
            end
          else
            alias_name = if json["alias"]["name"].nil?
              if json["alias"]["type"] == "s3" then @name else domain end
            else
              json["alias"]["name"].chomp(".")
            end
            @alias_target = AliasTarget.new(
              alias_name,
              json["alias"]["type"],
              zone_id
            )
          end
        end
      end

      # Public: Populate this RecordConfig from an AWS resource.
      #
      # aws     - the aws resource
      # domain  - the domain of the parent hosted zone
      def populate(aws, domain)
        @name = aws.name.chomp(domain).chomp(".")
        @ttl = aws.ttl
        @type = aws.type
        if !aws.resource_records.nil?
          if @type == "TXT" or @type == "SPF"
            @value = aws.resource_records.map { |r| r.value[1..-2] }
          else
            @value = aws.resource_records.map(&:value)
          end
        end

        if !aws.alias_target.nil?
          if aws.alias_target.dns_name.include? "elb"
            @alias_target = AliasTarget.new(
              Cumulus::ELB::get_aws_by_dns_name(aws.alias_target.elb_dns_name).load_balancer_name,
              "elb",
              nil
            )
          elsif aws.alias_target.dns_name.include? "s3"
            @alias_target = AliasTarget.new(nil, "s3", nil)
          elsif aws.alias_target.dns_name.include? "cloudfront"
            @alias_target = AliasTarget.new(nil, "cloudfront", nil)
          else
            @alias_target = AliasTarget.new(aws.alias_target.dns_name.chomp("."), "record", nil)
          end
        end
      end

      # Public: Get the config as a hash
      #
      # Returns the hash
      def to_hash
        {
          "name" => @name,
          "type" => @type,
          "ttl" => @ttl,
          "value" => @value,
          "alias" => if @alias_target.nil? then nil else @alias_target.to_hash end,
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the RecordDiffs that were found
      def diff(aws)
        diffs = []

        if @ttl != aws.ttl
          diffs << SingleRecordDiff.new(RecordChange::TTL, aws, self)
        end
        if !@value.nil? and @value.sort != aws.resource_records.map(&:value).sort
          diffs << SingleRecordDiff.new(RecordChange::VALUE, aws, self)
        end
        if !@alias_target.nil?
          if aws.alias_target.nil? or
            (is_elb_alias? and aws.alias_target.elb_dns_name != ELB::get_aws(@alias_target.name).dns_name) or
            (aws.alias_target.chomped_dns != @alias_target.dns_name)
            diffs << SingleRecordDiff.new(RecordChange::ALIAS, aws, self)
          end
        end

        diffs
      end

      # Public: Determine if the record is an alias for an ELB
      #
      # Returns whether this record is an alias for an ELB
      def is_elb_alias?
        !@alias_target.nil? and @alias_target.is_elb?
      end

      # Public: Determine if the recourd is an alias for another record
      #
      # Returns whether this record is an alias for another record
      def is_record_set_alias?
        !@alias_target.nil? and @alias_target.is_record_set?
      end

      # Public: Determine if the record is an alias for an S3 website
      #
      # Returns whether this record is an alias for an S3 website
      def is_s3_alias?
        !@alias_target.nil? and @alias_target.is_s3?
      end

      # Public: Determine if the record is an alias for a Cloudfront distribution
      #
      # Returns whether this record is an alias for a Cloudfront distribution
      def is_cloudfront_alias?
        !@alias_target.nil? and @alias_target.is_cloudfront?
      end

      # Public: Produce a `resource_records` array that is analogous to the one used in AWS from
      # the values array used by Cumulus
      #
      # Returns the `resource_records`
      def resource_records
        if !@value.nil?
          @value.map { |v| { value: v } }
        end
      end

      # Public: Produce a useful human readable version of the name of this RecordConfig
      #
      # Returns the string name
      def readable_name
        "(#{@type}) #{@name}"
      end
    end
  end
end
