require "security/models/SecurityGroupDiff"

# Public: An object representing configuration for a security group
class SecurityGroupConfig

  attr_reader :name
  attr_reader :description
  attr_reader :vpc_id
  attr_reader :tags

  # Public: Constructor.
  #
  # name - the name of the security group
  # json - a hash containing the JSON configuration for the security group
  def initialize(name, json)
    @name = name
    if !json.nil?
      @description = json["description"]
      @vpc_id = json["vpc-id"]
      @tags = json["tags"]
    end
  end

  # Public: Produce an array of the differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the aws resource
  #
  # Returns an array of the SecurityGroupDiffs that were found
  def diff(aws)
    diffs = []

    if @description != aws.description
      diffs << SecurityGroupDiff.new(SecurityGroupChange::DESCRIPTION, aws, self)
    end
    if @vpc_id != aws.vpc_id
      diffs << SecurityGroupDiff.new(SecurityGroupChange::VPC_ID, aws, self)
    end
    if @tags != Hash[aws.tags.map { |t| [t.key, t.value] }]
      diffs << SecurityGroupDiff.new(SecurityGroupChange::TAGS, aws, self)
    end

    diffs
  end
end
