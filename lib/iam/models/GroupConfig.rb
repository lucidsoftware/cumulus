require "iam/models/IamDiff"
require "iam/models/ResourceWithPolicy"
require "util/Colors"

module Cumulus
  module IAM
    # Public: Represents a config file for a group
    class GroupConfig < ResourceWithPolicy

      attr_accessor :users

      # Public: Constructor
      #
      # name - the name of the group
      # json - the Hash containing the JSON configuration for this GroupConfig, if
      #        nil, this will be an "empty GroupConfig"
      def initialize(name = nil, json = nil)
        super(name, json)
        @type = "group"
        @users = json["users"] unless json.nil?
      end

      # override diff to check for changes in users
      def diff(aws_resource)
        differences = super(aws_resource)

        aws_users = aws_resource.users.map { |user| user.name }
        new_users = @users.select { |local| !aws_users.include?(local) }
        unmanaged = aws_users.select { |aws| !@users.include?(aws) }

        if !unmanaged.empty? or !new_users.empty?
          differences << IamDiff.users(new_users, unmanaged)
        end

        differences
      end

    end
  end
end
