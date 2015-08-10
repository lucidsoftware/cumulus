require "common/manager/Manager"
require "conf/Configuration"
require "route53/loader/Loader"
require "route53/models/ZoneDiff"
require "util/Colors"

require "aws-sdk"

class Route53 < Manager
  def initialize
    super()
    @create_asset = false
    @route53 = Aws::Route53::Client.new(region: Configuration.instance.region)
  end

  def resource_name
    "Zone"
  end

  def local_resources
    @local_resources ||= Hash[Loader.zones.map { |local| [local.id, local] }]
  end

  def aws_resources
    @aws_resources ||= init_aws_resources
  end

  def unmanaged_diff(aws)
    ZoneDiff.unmanaged(aws)
  end

  def added_diff(local)
    ZoneDiff.added(local)
  end

  def diff_resource(local, aws)
    local.diff(aws)
  end

  def update(local, diffs)
    diffs.each do |diff|
      case diff.type
      when ZoneChange::COMMENT
        puts Colors.blue("\tupdating comment...")
        update_comment(local.id, local.comment)
      when ZoneChange::DOMAIN
        puts "\tAWS doesn't allow you to change the domain for a zone."
      when ZoneChange::PRIVATE
        puts "\tAWS doesn't allow you to change whether a zone is private."
      end
    end
  end

  private

  # Internal: Update the comment associated with a zone.
  #
  # id      - the id of the zone to update
  # comment - the new comment
  def update_comment(id, comment)
    @route53.update_hosted_zone_comment({
      id: id,
      comment: comment
    })
  end

  def init_aws_resources
    aws = @route53.list_hosted_zones()
    Hash[aws.hosted_zones.map { |z| [z.id, z] }]
  end
end
