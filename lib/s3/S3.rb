require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module S3
    class << self
      def client(region = nil)
        @clients ||= {}
        if !region then region = "us-east-1" end
        @clients[region] ||= Aws::S3::Client.new(Configuration.instance.client.merge({:force_path_style => true, :region => region}))
      end

      @@zone_ids = {
        "ap-northeast-1" => "Z2M4EHUR26P7ZW",
        "ap-southeast-1" => "Z3O0J2DXBE1FTB",
        "ap-southeast-2" => "Z1WCIGYICN2BYD",
        "eu-central-1" => "Z21DNDUVLTQW6Q",
        "eu-west-1" => "Z1BKCTXD74EZPE",
        "sa-east-1" => "Z7KQH4QJS55SO",
        "us-east-1" => "Z3AQBSTGFYJSTF",
        "us-gov-west-1" => "Z31GFT0UA1I2HV",
        "us-west-1" => "Z2F56UZL2M1ACD",
        "us-west-2" => "Z3BJ6K6RIION7M",
      }

      # Public: A mapping of region name to its hosted zone id. This mapping is needed because
      # the S3 API doesn't expose the hosted ids, you have to get them at
      # http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region.
      def zone_ids
        @@zone_ids
      end

      # Public: Static method that will get an S3 bucket from AWS by its name
      #
      # name - the name of the bucket to get
      #
      # Returns the Aws::S3::Types::Bucket by that name
      def get_aws(name)
        buckets.fetch(name)
      rescue KeyError
        puts "No S3 bucket named #{name}"
        exit
      end

      # Public: Get the full data for a bucket. Lazily loads resources only once.
      #
      # bucket_name - the name of the bucket to get
      #
      # Returns the full bucket
      def full_bucket(bucket_name)
        @monkey_patched ||= monkey_patch_bucket
        @full_buckets ||= Hash.new

        bucket = buckets[bucket_name]
        @full_buckets[bucket_name] ||= Aws::S3::Bucket.new(name: bucket_name, client: client(bucket.location))
      end

      # Public: Provide a mapping of S3 buckets to their names. Lazily loads resources.
      #
      # Returns the buckets mapped to their names
      def buckets
        @buckets ||= init_buckets
      end

      private

      # Internal: Monkey patch Bucket so it can get its location
      def monkey_patch_bucket
        require "aws_extensions/s3/Bucket"
        Aws::S3::Types::Bucket.send(:include, AwsExtensions::S3::Types::Bucket)
        true
      end

      # Internal: Load the buckets and map them to their names.
      #
      # Returns the buckets mapped to their names
      def init_buckets
        Hash[client.list_buckets.buckets.map { |bucket| [bucket.name, bucket] }]
      end
    end
  end
end
