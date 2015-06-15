require "conf/Configuration"
require "iam/loader/Loader"
require "iam/models/Diff"
require "util/Colors"

require "aws-sdk"

# Public: The main class for the IAM Manager application.
class Iam

  attr_reader :roles

  # Public: Constructor
  def initialize
    iam = Aws::IAM::Client.new(
      region: Configuration.instance.region
    )
    @roles = IamRoles.new(iam)
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

    # Public: Update a resource in AWS
    #
    # resource  - the resource to update
    # config    - the config object to be used when updating the resource
    def update(resource, config)
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
          update(resource, difference.config)
        elsif difference.type == ChangeType::REMOVE_POLICY
          puts Colors.red("#{difference.name} has policies not managed by Cumulus")
        else
          puts Colors.blue("updating #{difference.name}...")
          aws_resource = aws[difference.name]
          update(aws_resource, difference.config)
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
    #                             managed by Cumulus
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
            differences << Diff.new(name, ChangeType::REMOVE, @type, nil)
          end
        end
      end

      local.each do |name, resource|
        if !aws.key?(name)
          differences << Diff.new(name, ChangeType::ADD, @type, resource)
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
    @type = "role"

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

    def update(resource, config)
        if !config.policy.empty?
          resource = resource.policy(config.generated_policy_name)
          resource.put({
            :policy_document => config.policy.as_pretty_json
          })
        else
          puts Colors.red("Policy is empty. Not uploaded")
        end
    end

  end

end
