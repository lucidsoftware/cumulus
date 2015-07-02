require "common/models/Diff"
require "util/Colors"

# Public: The types of changes that can be made to Scheduled Actions
module ScheduledActionChange
  include DiffChange

  START = DiffChange::next_change_id
  ENDTIME = DiffChange::next_change_id
  RECURRENCE = DiffChange::next_change_id
  MIN = DiffChange::next_change_id
  MAX = DiffChange::next_change_id
  DESIRED = DiffChange::next_change_id
end

# Public: Represents a single difference between local configuration and AWS
# configuration of Scheduled Actions
class ScheduledActionDiff < Diff
  include ScheduledActionChange

  def diff_string
    case @type
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

  def asset_type
    "Scheduled action"
  end

  def aws_name
    @aws.scheduled_action_name
  end
end
