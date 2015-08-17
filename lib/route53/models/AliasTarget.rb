require "cloudfront/CloudFront"
require "elb/ELB"
require "s3/S3"

module Cumulus
  module Route53
    # Public: A struct that matches the structure of the AWS alias target struct
    AliasTarget = Struct.new(:name, :type, :local_zone_id) do
      # Public: Produce the dns_name for this alias
      #
      # Returns the dns_name
      def dns_name
        if is_elb?
          "dualstack.#{ELB::get_aws(name).dns_name}"
        elsif is_s3?
          "s3-website-#{S3::get_aws(name).location}.amazonaws.com"
        elsif is_cloudfront?
          CloudFront::get_aws(name).domain_name
        else
          name
        end
      end

      # Public: Produce a hash representing this alias target
      #
      # Returns the hash
      def to_hash
        {
          "name" => name,
          "type" => type
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce the hosted_zone_id for this alias
      #
      # Returns the hosted_zone_id
      def hosted_zone_id
        if is_elb?
          ELB::get_aws(name).canonical_hosted_zone_name_id
        elsif is_record_set?
          local_zone_id
        elsif is_s3?
          S3::zone_ids[S3::get_aws(name).location]
        elsif is_cloudfront?
          "Z2FDTNDATAQYW2" # AWS hard codes this
        end
      end

      # Public: Determine whether to evaluate the health check on the target. Always
      # false.
      #
      # Returns false
      def evaluate_target_health
        false
      end

      # Public: Determine if this alias is for an ELB
      #
      # Returns true if the alias is an ELB
      def is_elb?
        type.downcase == "elb"
      end

      # Public: Determine if this alias is for a record set
      #
      # Returns true if the alias is for a record set
      def is_record_set?
        type.downcase == "record"
      end

      # Public: Determine if this alias is for an s3 website
      #
      # Returns true if the alias is for an s3 website
      def is_s3?
        type.downcase == "s3"
      end

      # Public: Determine if this alias is for a Cloudfront distribution
      #
      # Returns true if the alias is for a Cloudfront distribution
      def is_cloudfront?
        type.downcase == "cloudfront"
      end
    end
  end
end
