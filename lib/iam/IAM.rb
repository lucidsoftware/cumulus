require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module IAM
    class << self
      @@client = Aws::IAM::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)

      # Public: Static method that will get the ARN of an IAM Role
      #
      # name - the name of the role to get
      #
      # Returns the String ARN or nil if there is no role
      def get_role_arn(name)
        @@client.get_role({
          role_name: name
        }).role.arn
      rescue Aws::IAM::Errors::NoSuchEntity
        nil
      end
    end
  end
end
