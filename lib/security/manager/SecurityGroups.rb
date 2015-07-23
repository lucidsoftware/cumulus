require "common/manager/Manager"
require "conf/Configuration"
require "security/loader/Loader"
require "security/models/SecurityGroupDiff"

require "aws-sdk"

class SecurityGroups < Manager
  def initialize
    @ec2 = Aws::EC2::Client.new(region: Configuration.instance.region)
  end

  def resource_name
    "Security Group"
  end

  def local_resources
    @local_resources ||= Hash[Loader.groups.map { |local| [local.name, local] }]
  end

  def aws_resources
    @aws_resources ||= init_aws_resources
  end

  def unmanaged_diff(aws)
    SecurityGroupDiff.unmanaged(aws)
  end

  def added_diff(local)
    SecurityGroupDiff.added(local)
  end

  def diff(local, aws)
    local.diff(aws)
  end

  def create(local)
    result = @ec2.create_security_group({
      group_name: local.name,
      description: local.description,
      vpc_id: local.vpc_id,
    })
    security_group_id = result.group_id
    update_tags(security_group_id, local.tags, {})
  end

  def update(local, diffs)
    diffs_by_type = diffs.group_by(&:type)

    if diffs_by_type.include?(SecurityGroupChange::VPC_ID)
      puts "\tUnfortunately, you can't change out the vpc id. You'll have to manually manage any dependencies on this security group, delete the security group, and recreate the security group with Cumulus if you'd like to change the vpc id."
    elsif diffs_by_type.include?(SecurityGroupChange::DESCRIPTION)
      puts "\tUnfortunately, AWS's SDK does not allow updating the description."
    else
      if diffs_by_type.include?(SecurityGroupChange::TAGS)
        tag_diff = diffs_by_type[SecurityGroupChange::TAGS][0]
        update_tags(tag_diff.aws.group_id, tag_diff.tags_to_add, tag_diff.tags_to_remove)
      end
    end
  end

  private

  # Internal: Update the tags associated with a security group.
  #
  # security_group_id - the id of the security group to update
  # add               - the tags to add (expects a hash of key value pairs)
  # remove            - the tags to remove (expects a hash of key value pairs)
  def update_tags(security_group_id, add, remove)
    if !add.empty?
      puts Colors.blue("\tadding tags...")
      @ec2.create_tags({
        resources: [security_group_id],
        tags: add.map { |k, v| { key: k, value: v } }
      })
    end
    if !remove.empty?
      puts Colors.blue("\tremoving tags...")
      @ec2.delete_tags({
        resources: [security_group_id],
        tags: remove.map { |k, v| { key: k, value: v } }
      })
    end
  end

  def init_aws_resources
    aws = @ec2.describe_security_groups()
    Hash[aws.security_groups.map { |a| [a.group_name, a] }]
  end
end
