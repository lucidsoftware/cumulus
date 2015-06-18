require "iam/loader/Loader"
require "iam/manager/IamResource"
require "util/Colors"

require "aws-sdk"

# Public: Manager class for IAM Roles.
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
    instance_profile = Aws::IAM::InstanceProfile.new(difference.name, { :client => @iam })
    instance_profile.add_role({
      :role_name => difference.name
    })
    role
  end

end
