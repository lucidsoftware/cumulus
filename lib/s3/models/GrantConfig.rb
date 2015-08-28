require "s3/models/GrantDiff"

module Cumulus
  module S3
    class GrantConfig
      @@all_permissions = ["list", "update", "view-permissions", "edit-permissions"].sort

      attr_reader :email
      attr_reader :name
      attr_reader :permissions


      # Public: A static method that will produce the Cumulus version of the permission
      # so that the names we use in Cumulus are a little closer to the names
      # in the AWS console.
      #
      # aws_permission - the string permission to convert
      #
      # Returns an array of the Cumulus version of the permission
      def self.to_cumulus_permission(aws_permission)
        case aws_permission
        when "FULL_CONTROL"
          @@all_permissions
        when "WRITE"
          ["update"]
        when "READ"
          ["list"]
        when "WRITE_ACP"
          ["edit-permissions"]
        when "READ_ACP"
          ["view-permissions"]
        end
      end

      # Public: A static method that will produce the AWS version of the
      # permission.
      #
      # cumulus_permission - the string permission to convert
      #
      # Returns the converted permission string
      def self.to_aws_permission(cumulus_permission)
        case cumulus_permission
        when "update"
          "WRITE"
        when "list"
          "READ"
        when "edit-permissions"
          "WRITE_ACP"
        when "view-permissions"
          "READ_ACP"
        end
      end

      # Public: Constructor
      #
      # json - a hash representing the JSON configuration. Expects to be passed
      #        an object from the "grants" array of S3 bucket configuration.
      def initialize(json = nil)
        if json
          @name = json["name"]
          @email = json["email"]
          @id = json["id"]
          @permissions = json["permissions"].sort
          if @permissions.include?("all")
            @permissions = (@permissions + @@all_permissions - ["all"]).uniq.sort
          end
        end
      end

      # Public: Populate this GrantConfig from the avlues in an
      # Aws::S3::Types::Grant
      #
      # aws - the aws object to populate from
      def populate!(aws)
        @name = if aws.grantee.type == "CanonicalUser"
          aws.grantee.display_name
        else
          case aws.grantee.uri
          when "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
            "AuthenticatedUsers"
          when "http://acs.amazonaws.com/groups/global/AllUsers"
            "Everyone"
          when "http://acs.amazonaws.com/groups/s3/LogDelivery"
            "LogDelivery"
          end
        end
        @email = aws.grantee.email_address
        @permissions = GrantConfig.to_cumulus_permission(aws.permission)
        @id = aws.grantee.id
      end

      # Public: Produce an AWS compatible array of hashes representing this
      # GrantConfig.
      #
      # Returns the array of hashes.
      def to_aws
        @permissions.map do |permission|
          if @name == "AuthenticatedUsers"
            type = "Group"
            uri = "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
          elsif @name == "Everyone"
            type = "Group"
            uri = "http://acs.amazonaws.com/groups/global/AllUsers"
          elsif @name == "LogDelivery"
            type = "Group"
            uri = "http://acs.amazonaws.com/groups/s3/LogDelivery"
          elsif @email
            type = "AmazonCustomerByEmail"
          else
            type = "CanonicalUser"
            display_name = @name
          end

          {
            grantee: {
              display_name: if !@email then @name end,
              email_address: if @email then @email end,
              id: if !@email then @id end,
              type: type,
              uri: uri,
            }.reject { |k, v| v.nil? },
            permission: GrantConfig.to_aws_permission(permission)
          }
        end
      end

      # Public: Converts this GrantConfig to a hash that matches Cumulus
      # configuration.
      #
      # Returns the hash
      def to_h
        {
          name: @name,
          id: @id,
          email: @email,
          permissions: if @permissions.sort == @@all_permissions then ["all"] else @permissions.sort end,
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce an array of differences between this local configuration
      # and the configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the GrantDiffs that were found
      def diff(aws)
        diffs = []

        if @permissions != aws.permissions
          diffs << GrantDiff.new(GrantChange::PERMISSIONS, aws, self)
        end

        diffs
      end

      # Public: Add permissions to the permissions of this Grant.
      #
      # permissions - an Array of the permissions to add
      def add_permissions!(permissions)
        @permissions = (@permissions + permissions).uniq.sort
      end

      # Public: Check GrantConfig equality with other objects.
      #
      # other - the other object to check
      #
      # Returns whether this GrantConfig is equal to `other`
      def ==(other)
        if !other.is_a? GrantConfig or
            @name != other.name or
            @email != other.email or
            @permissions.sort != other.permissions.sort
          false
        else
          true
        end
      end

      # Public: Check if this GrantConfig is not equal to the other object
      #
      # other - the other object to check
      #
      # Returns whether this GrantConfig is not equal to `other`
      def !=(other)
        !(self == other)
      end
    end
  end
end
