require "conf/Configuration"
require "iam/loader/Loader"
require "iam/models/Diff"
require "util/Colors"

require "aws-sdk"

# Public: The main class for the IAM Manager application.
class Iam

  # Public: Print out the diff between the local configuration and the IAMS
  # in AWS
  def diff
    puts differences.join("\n")
  end

  # Public: Print out the diff between local configuration and AWS for one role
  #
  # role - the name of the role to diff
  def diff_one(role)
    puts one_difference(role)
  end

  # Public: Sync the local configuration with the configuration in AWS. Will
  # not delete roles that are not locally configured, also will not remove
  # inline policies that are not locally configured.
  def sync
    sync_changes(differences)
  end

  # Public: Sync the local configuration for one role with AWS
  #
  # name - the name of the role to sync
  def sync_one(name)
    sync_changes(one_difference(name))
  end

  # Internal: Sync all the changes passed into the function to AWS
  #
  # diffs - the differences to sync
  def sync_changes(diffs)
    aws = {}
    aws_roles.each do |role|
      aws[role.name] = role
    end

    diffs.each do |difference|
      if difference.type == ChangeType::REMOVE
        puts difference
      elsif difference.type == ChangeType::ADD
        puts Colors.blue("creating #{difference.role}")
        @iam.create_role({
          :role_name => difference.role,
          :assume_role_policy_document => difference.config.policy_document
        })
        role = Aws::IAM::Role.new(difference.role, { :client => @iam })
        update_policy(role, difference.config)
      elsif difference.type == ChangeType::REMOVE_POLICY
        puts Colors.red("#{difference.role} has policies not managed by Cumulus")
      else
        puts Colors.blue("updating #{difference.role}...")
        aws_role = aws[difference.role]
        update_policy(aws_role, difference.config)
      end
    end
  end
  private :sync_changes

  # Internal: Update the generated policy document for an aws role
  #
  # role    - the Aws::IAM::Role to update the policy for
  # config  - the RoleConfig to use to generate the policy
  def update_policy(role, config)
      role = role.policy(config.generated_policy_name)
      role.put({
        :policy_document => config.policy.as_pretty_json
      })
  end
  private :update_policy

  # Internal: Get all the differences between the local configuration and the
  # IAMS in AWS
  #
  # Returns and Array of Diff objects that represent the differences
  def differences
    local = {}
    Loader.roles.each do |role|
      local[role.name] = role
    end

    calculate_differences(local, true)
  end
  private :differences

  # Internal: Find the differences between local and AWS configuration for one
  # role.
  #
  # name - the name of the role to check
  #
  # Returns the differences
  def one_difference(name)
    local = {
      name => Loader.role(name)
    }

    calculate_differences(local, false)
  end
  private :one_difference

  # Internal: Find the differences between the local and AWS configurations.
  #
  # local                     - the local roles to check against
  # include_non_managed_roles - whether to show the roles in AWS that aren't
  #                             managed by Cumulus
  #
  # Returns an array of differences
  def calculate_differences(local, include_non_managed_roles)
    aws = {}
    aws_roles.each do |role|
      aws[role.name] = role
    end

    differences = []
    if include_non_managed_roles
      aws.each do |name, role|
        if !local.key?(name)
          differences << Diff.new(name, ChangeType::REMOVE, nil)
        end
      end
    end

    local.each do |name, role|
      if !aws.key?(name)
        differences << Diff.new(name, ChangeType::ADD, role)
      end
    end

    aws.each do |name, role|
      if local.key?(name)
        d = local[name].diff(role)
        if d.different?
          differences << d
        end
      end
    end

    differences
  end
  private :calculate_differences

  # Internal: Lazily load all the roles from AWS.
  #
  # Returns the Array of AWS roles
  def aws_roles
    @aws_roles ||= init_aws_roles
  end

  # Internal: Load all the roles from AWS
  #
  # Returns the Array of AWS roles
  def init_aws_roles
    @iam ||= Aws::IAM::Client.new(
      region: Configuration.instance.region
    )
    @iam.list_roles().roles.map do |role|
      Aws::IAM::Role.new(role.role_name, { :client => @iam })
    end
  end
  private :aws_roles

end
