require "common/manager/Manager"
require "conf/Configuration"
require "cloudfront/CloudFront"
require "cloudfront/loader/Loader"
require "cloudfront/models/DistributionDiff"
require "util/Colors"

require "aws-sdk"

module Cumulus
  module CloudFront
    class Manager < Common::Manager
      def initialize
        super()
        @create_asset = false
        @cloudfront = Aws::CloudFront::Client.new(region: Configuration.instance.region)
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

      def unmanaged_diff(aws)
        DistributionDiff.unmanaged(aws)
      end

      def added_diff(local)
        DistributionDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      def update(local, diffs)
        puts Colors.blue("\tupdates disabled")
      end

    end
  end
end
