require "common/models/Diff"
require "common/models/TagsDiff"
require "util/Colors"

# Public: The types of changes that can be made to security groups
module SecurityGroupChange
  include DiffChange

  DESCRIPTION = DiffChange::next_change_id
  VPC_ID = DiffChange::next_change_id
  TAGS = DiffChange::next_change_id
end

# Public: Represents a single difference between local configuration and AWS configuration
# of security groups
class SecurityGroupDiff < Diff
  include SecurityGroupChange
  include TagsDiff

  def asset_type
    "Security group"
  end

  def aws_name
    @aws.group_name
  end

  def diff_string
    case @type
    when DESCRIPTION
      [
        "Description:",
        Colors.aws_changes("\tAWS - #{@aws.description}"),
        Colors.local_changes("\tLocal - #{@local.description}"),
        "\tUnfortunately, AWS's SDK does not allow updating the description."
      ].join("\n")
    when TAGS
      tags_diff_string
    when VPC_ID
      [
        "VPC ID: AWS - #{Colors.aws_changes(@aws.vpc_id)}, Local - #{Colors.local_changes(@local.vpc_id)}",
        "\tUnfortunately, you can't change out the vpc id. You'll have to manually manage any dependencies on this security group, delete the security group, and recreate the security group with Cumulus if you'd like to change the vpc id."
      ].join("\n")
    end
  end
end
