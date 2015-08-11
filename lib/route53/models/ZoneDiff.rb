require "common/models/Diff"
require "util/Colors"

# Public: The types of changes that can be made to zones
module ZoneChange
  include DiffChange

  COMMENT = DiffChange::next_change_id
  DOMAIN = DiffChange::next_change_id
  PRIVATE = DiffChange::next_change_id
  VPC = DiffChange::next_change_id
end

# Public: Represents a single difference between local configuration and AWS
# configuration of zones.
class ZoneDiff < Diff
  include ZoneChange

  def asset_type
    "Zone"
  end

  def aws_name
    access = if @aws.config.private_zone then "private" else "public" end
    "#{@aws.name} (#{access})"
  end

  def add_string
    "has been added locally, but must be created in AWS manually."
  end

  def diff_string
    case @type
    when COMMENT
      [
        "Comment:",
        Colors.aws_changes("\tAWS - #{@aws.config.comment}"),
        Colors.local_changes("\tLocal - #{@local.comment}")
      ].join("\n")
    when DOMAIN
      [
        "Domain: AWS - #{Colors.aws_changes(@aws.name)}, Local - #{Colors.local_changes(@local.domain)}",
        "\tAWS doesn't allow you to change the domain for a zone."
      ].join("\n")
    when PRIVATE
      [
        "Private: AWS - #{Colors.aws_changes(@aws.config.private_zone)}, Local - #{Colors.local_changes(@local.private)}",
        "\tAWS doesn't allow you to change whether a zone is private."
      ].join("\n")
    when VPC
      [
        "VPCs:",
        added_vpc_ids.map { |vpc| Colors.added("\t#{vpc["id"]} | #{vpc["region"]}") },
        removed_vpc_ids.map { |vpc| Colors.removed("\t#{vpc["id"]} | #{vpc["region"]}") }
      ].flatten.join("\n")
    end
  end

  # Public: Get the VPCs that have been added locally.
  #
  # Returns an array of vpc ids
  def added_vpc_ids
    @local.vpc - @aws.vpc
  end

  # Public: Get the VPCs that have been removed locally.
  #
  # Returns an array of vpc ids
  def removed_vpc_ids
    @aws.vpc - @local.vpc
  end

end
