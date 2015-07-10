require "autoscaling/models/ScheduledActionDiff"

# Public: A class representing the configuration for a scheduled scaling action
class ScheduledConfig
  attr_accessor :desired
  attr_accessor :end
  attr_accessor :max
  attr_accessor :min
  attr_accessor :name
  attr_accessor :recurrence
  attr_accessor :start

  # Public: Constructor
  #
  # json - a hash representing the JSON configuration for this action
  def initialize(json = nil)
    if !json.nil?
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
  end

  # Public: Get the configuration as a hash
  #
  # Returns the hash
  def hash
    {
      "desired" => @desired,
      "end" => @end,
      "max" => @max,
      "min" => @min,
      "name" => @name,
      "recurrence" => @recurrence,
      "start" => @start
    }.reject { |k, v| v.nil? }
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

  # Public: Populate the ScheduledConfig from an existing AWS resource
  #
  # resource - the aws resource to populate from
  def populate(resource)
    @desired = resource.desired_capacity
    @end = resource.end_time
    @max = resource.max_size
    @min = resource.min_size
    @name = resource.scheduled_action_name
    @recurrence = resource.recurrence
    @start = resource.start_time
  end

end
