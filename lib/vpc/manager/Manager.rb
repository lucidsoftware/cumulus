require "common/manager/Manager"
require "conf/Configuration"
require "util/Colors"
require "vpc/loader/Loader"
require "ec2/EC2"

require "aws-sdk"
require "json"

module Cumulus
  module VPC
    class Manager < Common::Manager

      def initialize
        super()
        @vpc = Aws::EC2::Client.new(region: Configuration.instance.region)
      end

      def resource_name
        "Virtual Private Cloud"
      end

      def local_resources
        @local_resources ||= Hash[Loader.vpcs.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= EC2::named_vpcs
      end

      def unmanaged_diff(aws)
        VpcDiff.unmanaged(aws)
      end

      def added_diff(local)
        VpcDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      def update(local, diffs)
        puts "Updating Local: #{local}"
      end

      def create(local)
        puts "Creating Local: #{local}"
      end

    end
  end
end
