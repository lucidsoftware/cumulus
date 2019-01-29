require "iam/loader/Loader"
require "iam/manager/IamResource"
require "iam/models/UserConfig"

require "aws-sdk-iam"

module Cumulus
  module IAM
    # Public: Manager class for IAM Users
    class IamUsers < IamResource

      def initialize(iam)
        super(iam)
        @type = "user"
        @migration_dir = "users"
      end

      def local_resources
        local = {}
        Loader.users.each do |user|
          local[user.name] = user
        end
        local
      end

      def one_local(name)
        Loader.user(name)
      end

      def aws_resources
        @aws_users ||= init_aws_users
      end

      def init_aws_users
        @iam.list_users().users.map do |user|
          Aws::IAM::User.new(user.user_name, { :client => @iam })
        end
      end
      private :init_aws_users

      def create(difference)
        @iam.create_user({
          :user_name => difference.local.name
        })
        Aws::IAM::User.new(difference.local.name, { :client => @iam })
      end

      def empty_config
        UserConfig.new
      end

    end
  end
end
