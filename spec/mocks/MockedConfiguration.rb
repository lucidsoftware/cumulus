require "util/DeepMerge"

module Cumulus
  module Test
    module MockedConfiguration
      def self.included(base)
        base.instance_eval do
          include Cumulus::Test::Util::DeepMerge

          def stub(overrides = nil)
            overridden = Util::DeepMerge.deep_merge(@@default_config, overrides)
            init_from_hash(overridden, '/mocked', nil, nil, false)
          end

          stub
        end
      end

      @@default_config = {
        "stub_aws_responses" => true,
        "colors-enabled" => false,
        "iam" => {
          "policies" => {
            "prefix" => "",
            "suffix" => "",
            "version" => "",
          },
        },
        "autoscaling" => {
          "groups" => {
            "override-launch-config-on-sync" => false,
          },
        },
        "route53" => {
          "print-all-ignored" => true,
        },
        "s3" => {
          "print-progress" => true,
        },
        "security" => {
          "outbound-default-all-allowed" => true,
          "subnet-files" => [
            "security-groups/subnets.json",
          ],
        },
        "ec2" => {
          "instances" => {
            "ignore-unmanaged" => true,
            "default-image-id" => nil,
            "volume-mounting" => {
              "base" => "/dev/xvd",
              "start" => "f",
              "end" => "z",
            },
          },
        },
        "region" => "us-east-1",
      }
    end
  end
end
