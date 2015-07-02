require "autoscaling/models/ScheduledActionDiff"

# Public: A class representing the configuration for a scheduled scaling action
class ScheduledConfig
  attr_reader :desired
  attr_reader :end
  attr_reader :max
  attr_reader :min
  attr_reader :name
  attr_reader :recurrence
  attr_reader :start

  # Public: Constructor
  #
  # json - a hash representing the JSON configuration for this action
  def initialize(json)
    @name = json["name"]
    if !json["start"].nil? and json["start"] != ""
      @start = Time.parse(json["start"])
    end
    if !json["end"].nil? and json["end"] != ""
      @end = Time.parse(json["end"])
    end
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

    # we check if start is nil, cause even in the case that it is nil, aws
    # will still give the scheduled action a start time on creation. This is
    # annoying, because it will make it seem as if start time is always changed.
    if @start != aws.start_time and !@start.nil?
      diffs << ScheduledActionDiff.new(ScheduledActionChange::START, aws, self)
    end
    if @end != aws.end_time
      diffs << ScheduledActionDiff.new(ScheduledActionChange::ENDTIME, aws, self)
    end
    if @recurrence != aws.recurrence
      diffs << ScheduledActionDiff.new(ScheduledActionChange::RECURRENCE, aws, self)
    end
    if @min != aws.min_size
      diffs << ScheduledActionDiff.new(ScheduledActionChange::MIN, aws, self)
    end
    if @max != aws.max_size
      diffs << ScheduledActionDiff.new(ScheduledActionChange::MAX, aws, self)
    end
    if @desired != aws.desired_capacity
      diffs << ScheduledActionDiff.new(ScheduledActionChange::DESIRED, aws, self)
    end

    diffs
  end

end
