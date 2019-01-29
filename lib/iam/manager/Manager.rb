require "conf/Configuration"
require "iam/manager/IamGroups"
require "iam/manager/IamRoles"
require "iam/manager/IamUsers"

require "aws-sdk-iam"

module Cumulus
  module IAM

    # Public: The main class for the IAM management module.
    class Manager

      attr_reader :groups
      attr_reader :roles
      attr_reader :users

      # Public: Constructor
      def initialize
        iam = Aws::IAM::Client.new(Configuration.instance.client)

        @groups = IamGroups.new(iam)
        @roles = IamRoles.new(iam)
        @users = IamUsers.new(iam)
      end

    end
  end
end
