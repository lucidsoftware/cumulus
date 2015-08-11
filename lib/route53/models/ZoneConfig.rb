require "route53/models/RecordConfig"
require "route53/models/Vpc"
require "route53/models/ZoneDiff"

# Public: An object representing configuration for a zone
class ZoneConfig
  attr_reader :comment
  attr_reader :domain
  attr_reader :id
  attr_reader :name
  attr_reader :private
  attr_reader :records
  attr_reader :vpc

  # Public: Constructor
  #
  # json - a hash containing the JSON configuration for the zone
  def initialize(name, json = nil)
    @name = name
    if !json.nil?
      @id = "/hostedzone/#{json["zone-id"]}"
      @domain = json["domain"]
      @private = json["private"]
      @vpc = if @private then json["vpc"].map { |v| Vpc.new(v["id"], v["region"]) } else [] end
      @comment = json["comment"]
      @records = json["records"].map(&RecordConfig.method(:new))

    end
  end

  # Public: Produce an array of differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the AWS resource
  #
  # Returns an array of the ZoneDiffs that were found
  def diff(aws)
    diffs = []

    if @comment != aws.config.comment
      diffs << ZoneDiff.new(ZoneChange::COMMENT, aws, self)
    end
    if @domain != aws.name and "#{@domain}." != aws.name
      diffs << ZoneDiff.new(ZoneChange::DOMAIN, aws, self)
    end
    if @private != aws.config.private_zone
      diffs << ZoneDiff.new(ZoneChange::PRIVATE, aws, self)
    end
    if @private and @vpc.sort != aws.vpc.sort
      diffs << ZoneDiff.new(ZoneChange::VPC, aws, self)
    end

    diffs
  end
end
