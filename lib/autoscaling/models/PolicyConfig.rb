require "autoscaling/models/PolicyDiff"

# Public: A class that encapsulates data about the way a scaling policy is
# configured.
class PolicyConfig
  attr_reader :adjustment
  attr_reader :adjustment_type
  attr_reader :cooldown
  attr_reader :min_adjustment
  attr_reader :name

  # Public: Constructor
  #
  # json - a hash representing the JSON configuration for this scaling policy
  def initialize(json)
    @name = json["name"]
    @adjustment_type = json["adjustment-type"]
    @adjustment = json["adjustment"]
    @cooldown = json["cooldown"]
    @min_adjustment = json["min-adjustment-step"]
  end

  # Public: Produce the differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the scaling policy in AWS
  def diff(aws)
    diffs = []

    if @adjustment_type != aws.adjustment_type
      diffs << PolicyDiff.new(PolicyChange::ADJUSTMENT_TYPE, aws, self)
    elsif @adjustment != aws.scaling_adjustment
      diffs << PolicyDiff.new(PolicyChange::ADJUSTMENT, aws, self)
    elsif @cooldown != aws.cooldown
      diffs << PolicyDiff.new(PolicyChange::COOLDOWN, aws, self)
    elsif @min_adjustment != aws.min_adjustment_step
      diffs << PolicyDiff.new(PolicyChange::MIN_ADJUSTMENT, aws, self)
    end

    diffs
  end

end
