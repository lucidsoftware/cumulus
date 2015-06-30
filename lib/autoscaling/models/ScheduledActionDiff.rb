require "util/Colors"

# Public: The types of changes that can be made to Scheduled Actions
module ScheduledActionChange
  ADD = 1
  UNMANAGED = 2
  START = 3
  ENDTIME = 4
  RECURRENCE = 5
  MIN = 6
  MAX = 7
  DESIRED = 8
end

# Public: Represents a single difference between local configuration and AWS
# configuration of Scheduled Actions
class ScheduledActionDiff
  include ScheduledActionChange

  attr_reader :aws, :local, :type

  # Public: Static method that will produce an "unmanaged" diff
  #
  # aws - the aws resource that is unmanaged
  #
  # Returns the diff
  def ScheduledActionDiff.unmanaged(aws)
    ScheduledActionDiff.new(UNMANAGED, aws)
  end

  # Public: Static method that will produce an "added" diff
  #
  # local - the local configuration that is added
  #
  # Returns the diff
  def ScheduledActionDiff.added(local)
    ScheduledActionDiff.new(ADD, nil, local)
  end

  # Public: Constructor
  #
  # type  - the type of the difference
  # aws   - the aws resource that's different (defaults to nil)
  # local - the local resource that's difference (defaults to nil)
  def initialize(type, aws = nil, local = nil)
    @aws = aws
    @local = local
    @type = type
  end

  def to_s
    case @type
    when ADD
      Colors.added("Scheduled Action #{@local.name} will be created")
    when UNMANAGED
      Colors.unmanaged("Scheduled Action #{@aws.scheduled_action_name} is not managed by Cumulus")
    when START
      "Start: AWS - #{Colors.aws_changes(@aws.start_time)}, Local - #{Colors.local_changes(@local.start)}"
    when ENDTIME
    when RECURRENCE
      "End: AWS - #{Colors.aws_changes(@aws.end_time)}, Local - #{Colors.local_changes(@local.end)}"
      "Recurrence: AWS - #{Colors.aws_changes(@aws.recurrence)}, Local - #{Colors.local_changes(@local.recurrence)}"
    when MIN
      "Min size: AWS - #{Colors.aws_changes(@aws.min_size)}, Local - #{Colors.local_changes(@local.min)}"
    when MAX
      "Max size: AWS - #{Colors.aws_changes(@aws.max_size)}, Local - #{Colors.local_changes(@local.max)}"
    when DESIRED
      "Desired capacity: AWS - #{Colors.aws_changes(@aws.desired_capacity)}, Local - #{Colors.local_changes(@local.desired)}"
    end
  end
end
