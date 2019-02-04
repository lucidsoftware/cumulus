require "conf/Configuration"

require "aws-sdk-iam"

module Cumulus
  module IAM
    class << self
      @@client = Aws::IAM::Client.new(Configuration.instance.client)

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

      # Public: Get the instance profile arn for a role
      #
      # name - the name of the role
      def get_instance_profile_arn(name)
        @@client.get_instance_profile({
          instance_profile_name: name
        }).instance_profile.arn
      rescue Aws::IAM::Errors::NoSuchEntity
        nil
      end

    end
  end
end
