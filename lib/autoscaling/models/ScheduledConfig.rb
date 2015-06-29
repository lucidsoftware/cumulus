require "autoscaling/models/ScheduledActionDiff"

# Public: A class representing the configuration for a scheduled scaling action
class ScheduledConfig
  attr_reader :name

  # Public: Constructor
  #
  # json - a hash representing the JSON configuration for this action
  def initialize(json)
    @name = json["name"]
    @start = json["start"]
    @end = json["end"]
    @recurrence = json["recurrence"]
    @min = json["min"]
    @max = json["max"]
    @desired = json["desired"]
  end

  # Public: Produce the differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the scheduled action in AWS
  def diff(aws)
    diffs = []

    if @start != aws.start_time
      diffs << ScheduledActionDiff.new(ScheduledActionChange::START, aws, self)
    elsif @end != aws.end_time
      diffs << ScheduledActionDiff.new(ScheduledActionChange::ENDTIME, aws, self)
    elsif @recurrence != aws.recurrence
      diffs << ScheduledActionDiff.new(ScheduledActionChange::RECURRENCE, aws, self)
    elsif @min != aws.min_size
      diffs << ScheduledActionDiff.new(ScheduledActionChange::MIN, aws, self)
    elsif @max != aws.max_size
      diffs << ScheduledActionDiff.new(ScheduledActionChange::MAX, aws, self)
    elsif @desired != aws.desired_capacity
      diffs << ScheduledActionDiff.new(ScheduledActionChange::DESIRED, aws, self)
    end

    diffs
  end

end
