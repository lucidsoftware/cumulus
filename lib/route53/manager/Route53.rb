require "common/manager/Manager"
require "conf/Configuration"
require "route53/loader/Loader"
require "route53/models/Vpc"
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
      when ZoneChange::VPC
        update_vpc(local.id, diff.added_vpc_ids, diff.removed_vpc_ids)
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

  # Internal: Update the VPCs associated with a zone.
  #
  # id         - the id of the zone to update
  # associate  - the vpc ids to associate with the zone
  # dissociate - the vpc ids to dissociate from the zone
  def update_vpc(id, associate, dissociate)
    if !associate.empty?
      puts Colors.blue("\tassociating VPCs...")
      associate.each do |vpc|
        @route53.associate_vpc_with_hosted_zone({
          hosted_zone_id: id,
          vpc: { vpc_id: vpc.id, vpc_region: vpc.region }
        })
      end
    end
    if !dissociate.empty?
      puts Colors.blue("\tdissociating VPCs...")
      dissociate.each do |vpc|
        @route53.disassociate_vpc_from_hosted_zone({
          hosted_zone_id: id,
          vpc: { vpc_id: vpc.id, vpc_region: vpc.region }
        })
      end
    end
  end

  # A struct that combines all the data about a hosted zone in AWS
  AwsZone = Struct.new(:id, :name, :config, :vpc, :route53) do
    def records
      @records ||= get_zone_records
    end

    private

    # Internal: Get the records for this hosted zone.
    #
    # Returns an array of records belonging to the zone
    def get_zone_records(id)
      records = []
      all_records_retrieved = false
      next_record_name = nil
      next_record_type = nil
      next_record_identifier = nil

      until all_records_retrieved
        response = route53.list_resource_record_sets({
          hosted_zone_id: id,
          start_record_name: next_record_name,
          start_record_type: next_record_type,
          start_record_identitifier: next_record_identifier
        }.reject { |k, v| v.nil? })
        records << response.resource_record_sets
        next_record_name = response.next_record_name
        next_record_type = response.next_record_type
        next_record_identifier = response.next_record_identifier

        if !response.is_truncated
          all_records_retrieved = true
        end
      end

      records.flatten
    end
  end

  def init_aws_resources
    aws = @route53.list_hosted_zones().hosted_zones.map do |zone|
      vpc = if zone.config.private_zone
        @route53.get_hosted_zone(id: zone.id).vp_cs.map { |v| Vpc.new(v.vpc_id, v.vpc_region) }
      else
        nil
      end
      AwsZone.new(zone.id, zone.name, zone.config, vpc, @route53)
    end
    Hash[aws.map { |z| [z.id, z] }]
  end

end
