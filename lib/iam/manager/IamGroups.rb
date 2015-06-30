require "iam/loader/Loader"
require "iam/manager/IamResource"
require "iam/models/GroupConfig"
require "util/Colors"

require "aws-sdk"

# Public: Manager class for IAM Groups
class IamGroups < IamResource

  def initialize(iam)
    super(iam)
    @type = "group"
    @migration_dir = "groups"
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
    resource = Aws::IAM::Group.new(difference.name, { :client => @iam })
    add_users(resource, difference.config.users)
    resource
  end

  def update(resource, diff)
    super(resource, diff)
    add_users(resource, diff.added_users)
    diff.removed_users.each { |u| resource.remove_user({ :user_name => u }) }
  end

  def empty_config
    GroupConfig.new
  end

  def migrate_additional(configs_to_aws)
    configs_to_aws.map do |config, resource|
      config.users = resource.users.map { |u| u.name }
    end
  end

  private

  # Internal: Add the users assigned to the group to the group, handling the
  # case that the user doesn't exist
  #
  # resource - the aws group resource
  # users    - the users to add
  def add_users(resource, users)
    users.each do |u|
      begin
        resource.add_user({ :user_name => u })
      rescue Aws::IAM::Errors::NoSuchEntity
        puts Colors.red("\tNo such user #{u}!")
      end
    end
  end

end
