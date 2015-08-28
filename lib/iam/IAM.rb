require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module IAM
    class << self
      @@client = Aws::IAM::Client.new(region: Configuration.instance.region)

      # Public: Static method that will get the ARN of an IAM Role
      #
      # name - the name of the role to get
      #
      # Returns the String ARN
      def get_role_arn(name)
        @@client.get_role({
          role_name: name
        }).role.arn
      rescue Aws::IAM::Errors::NoSuchEntity
        puts "No IAM role named #{name}"
        exit
      end
    end
  end
end
