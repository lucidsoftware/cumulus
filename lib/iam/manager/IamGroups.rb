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

  def empty_config
    GroupConfig.new
  end

  def migrate_additional(configs_to_aws)
    configs_to_aws.map do |config, resource|
      config.users = resource.users.map { |u| u.name }
    end
  end

end
