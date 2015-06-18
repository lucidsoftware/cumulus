require "conf/Configuration"
require "iam/loader/Loader"
require "iam/models/Diff"
require "util/Colors"

require "aws-sdk"

# Public: The main class for the IAM Manager application.
class Iam

  attr_reader :groups
  attr_reader :roles
  attr_reader :users

  # Public: Constructor
  def initialize
    iam = Aws::IAM::Client.new(
      region: Configuration.instance.region
    )
    @groups = IamGroups.new(iam)
    @roles = IamRoles.new(iam)
    @users = IamUsers.new(iam)
  end

  class IamResource
    # =====================================================
    # Methods to be overridden
    # =====================================================
    # Public: Get the local resources
    #
    # Returns an array of resources
    def local_resources
      nil
    end

    # Public: Get one local resource
    #
    # name - the name of the resource to load
    #
    # Returns one local resource
    def one_local(name)
      nil
    end

    # Public: Get resources from AWS
    #
    # Returns an array of resources from AWS
    def aws_resources
      nil
    end

    # Public: Create a resource in AWS
    #
    # difference - the Diff object that contains the local differences
    #
    # Returns the created resource
    def create(difference)
      nil
    end

    # =====================================================
    # End methods to be overridden
    # =====================================================

    # Public: Constructor
    #
    # iam - the IAM client to use
    def initialize(iam)
      @iam = iam
    end

    # Public: Print out the diff between the local configuration and the IAMS
    # in AWS
    def diff
      puts differences.join("\n")
    end

    # Public: Print out the diff between local configuration and AWS for one
    # resource
    #
    # name - the name of the resource to diff
    def diff_one(name)
      puts one_difference(name)
    end

    # Public: Print out a list of resources defined by local configuration.
    def list
      names = local_resources.map do |name, resource|
        name
      end
      puts names.join(" ")
    end

    # Public: Sync the local configuration with the configuration in AWS. Will
    # not delete resources that are not locally configured; also will not remove
    # inline policies that are not locally configured.
    def sync
      sync_changes(differences)
    end

    # Public: Sync the local configuration for one resource with AWS
    #
    # name - the name of the resource to sync
    def sync_one(name)
      sync_changes(one_difference(name))
    end

    # Public: Update a resource in AWS
    #
    # resource  - the resource to update
    # diff    - the diff object to be used when updating the resource
    def update(resource, diff)
      if !diff.config.policy.empty?
        policy = resource.policy(diff.config.generated_policy_name)
        policy.put({
          :policy_document => diff.config.policy.as_pretty_json
        })
      else
        puts Colors.red("Policy is empty. Not uploaded")
      end

      if !diff.attached_policies.empty?
        diff.attached_policies.each do |arn|
          resource.attach_policy({ :policy_arn => arn })
        end
      end
      if !diff.detached_policies.empty?
        diff.detached_policies.each do |arn|
          resource.detach_policy({ :policy_arn => arn })
        end
      end
    end

    # Internal: Sync all the changes passed into the function to AWS
    #
    # diffs - the differences to sync
    def sync_changes(diffs)
      aws = {}
      aws_resources.each do |resource|
        aws[resource.name] = resource
      end

      diffs.each do |difference|
        if difference.type == ChangeType::REMOVE
          puts difference
        elsif difference.type == ChangeType::ADD
          puts Colors.blue("creating #{difference.name}")
          resource = create(difference)
          update(resource, difference)
        elsif difference.type == ChangeType::REMOVE_POLICY
          puts Colors.red("#{difference.name} has policies not managed by Cumulus")
        else
          puts Colors.blue("updating #{difference.name}...")
          aws_resource = aws[difference.name]
          update(aws_resource, difference)
        end
      end
    end
    private :sync_changes

    # Internal: Get all the differences between the local configuration and the
    # IAMS in AWS
    #
    # Returns and Array of Diff objects that represent the differences
    def differences
      calculate_differences(local_resources, true)
    end
    private :differences

    # Internal: Find the differences between local and AWS configuration for one
    # resource.
    #
    # name - the name of the resource to check
    #
    # Returns the differences
    def one_difference(name)
      local = {
        name => one_local(name)
      }

      calculate_differences(local, false)
    end
    private :one_difference

    # Internal: Find the differences between the local and AWS configurations.
    #
    # local               - the local resources to check against
    # include_non_managed - whether to show the resources in AWS that aren't
    #                       managed by Cumulus
    #
    # Returns an array of differences
    def calculate_differences(local, include_non_managed)
      aws = {}
      aws_resources.each do |resource|
        aws[resource.name] = resource
      end

      differences = []
      if include_non_managed
        aws.each do |name, resource|
          if !local.key?(name)
            differences << Diff.new(name, ChangeType::REMOVE, nil)
          end
        end
      end

      local.each do |name, resource|
        if !aws.key?(name)
          differences << Diff.new(name, ChangeType::ADD, resource)
        end
      end

      aws.each do |name, resource|
        if local.key?(name)
          d = local[name].diff(resource)
          if d.different?
            differences << d
          end
        end
      end

      differences
    end
    private :calculate_differences
  end

  class IamRoles < IamResource

    def initialize(iam)
      super(iam)
      @type = "role"
    end

    def local_resources
      local = {}
      Loader.roles.each do |role|
        local[role.name] = role
      end
      local
    end

    def one_local(name)
      Loader.role(name)
    end

    def aws_resources
      @aws_roles ||= init_aws_roles
    end

    # Internal: Load all the roles from AWS
    #
    # Returns the Array of AWS roles
    def init_aws_roles
      @iam.list_roles().roles.map do |role|
        Aws::IAM::Role.new(role.role_name, { :client => @iam })
      end
    end
    private :init_aws_roles

    def create(difference)
      # create the role
      @iam.create_role({
        :role_name => difference.name,
        :assume_role_policy_document => difference.config.policy_document
      })
      role = Aws::IAM::Role.new(difference.name, { :client => @iam })

      # try to create the instance profile, but if it already exists, just warn
      # the user
      begin
        @iam.create_instance_profile({
          :instance_profile_name => difference.name
        })
      rescue Aws::IAM::Errors::EntityAlreadyExists
        Colors.red("Instance profile already exists")
      end

      # assign the role to the instance profile
      instance_profile = Aws::IAM::InstanceProfile.new(difference.name, {:client => @iam })
      instance_profile.add_role({
        :role_name => difference.name
      })
      role
    end

  end

  class IamUsers < IamResource

    def initialize(iam)
      super(iam)
      @type = "user"
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
        :user_name => difference.name
      })
      Aws::IAM::User.new(difference.name, { :client => @iam })
    end

  end

  class IamGroups < IamResource

    def initialize(iam)
      super(iam)
      @type = "group"
    end

    def local_resources
      local = {}
      Loader.groups.each do |group|
        local[group.name] = group
      end
      local
    end

    def one_local(name)
      Loader.group(name)
    end

    def aws_resources
      @aws_groups ||= init_aws_groups
    end

    def init_aws_groups
      @iam.list_groups().groups.map do |group|
        Aws::IAM::Group.new(group.group_name, { :client => @iam })
      end
    end

    def create(difference)
      @iam.create_group({
        :group_name => difference.name
      })
      Aws::IAM::Group.new(difference.name, { :client => @iam })
    end

    def update(resource, diff)
      super(resource, diff)

      # add the users, handling the case that the user doesn't exist
      diff.added_users.each do |u|
        begin
          resource.add_user({ :user_name => u })
        rescue Aws::IAM::Errors::NoSuchEntity
          puts Colors.red("\tNo such user #{u}!")
        end
      end

      diff.removed_users.each { |u| resource.remove_user({ :user_name => u }) }
    end

  end

end
