require "conf/Configuration"
require "loader/Loader"
require "models/Diff"
require "util/Colors"

require "aws-sdk"

# Public: The main class for the IAM Manager application.
class Iam

  # Public: Print out the diff for between the local configuration and the IAMS
  # in AWS
  def diff
    puts differences.join("\n")
  end

  # Public: Sync the local configuration with the configuration in AWS. Will
  # not delete roles that are not locally configured, also will not remove
  # inline policies that are not locally configured.
  def sync
    aws = {}
    aws_roles.each do |role|
      aws[role.name] = role
    end

    differences.each do |difference|
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
        puts Colors.red("#{difference.role} has policies not managed by IAM Manager")
      else
        puts Colors.blue("updating #{difference.role}...")
        aws_role = aws[difference.role]
        update_policy(aws_role, difference.config)
      end
    end
  end

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

    aws = {}
    aws_roles.each do |role|
      aws[role.name] = role
    end

    differences = []
    aws.each do |name, role|
      if !local.key?(name)
        differences << Diff.new(name, ChangeType::REMOVE, nil)
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
  private :differences

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
