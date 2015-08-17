require "common/models/Diff"
require "util/Colors"

module Cumulus
  module AutoScaling
    # Public: The types of changes that can be made to Scheduled Actions
    module ScheduledActionChange
      include Common::DiffChange

      START = Common::DiffChange::next_change_id
      ENDTIME = Common::DiffChange::next_change_id
      RECURRENCE = Common::DiffChange::next_change_id
      MIN = Common::DiffChange::next_change_id
      MAX = Common::DiffChange::next_change_id
      DESIRED = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of Scheduled Actions
    class ScheduledActionDiff < Common::Diff
      include ScheduledActionChange

      def diff_string
        diff_lines = [@local.name]

        case @type
        when START
          diff_lines << "\t\tStart: AWS - #{Colors.aws_changes(@aws.start_time)}, Local - #{Colors.local_changes(@local.start)}"
        when ENDTIME
          diff_lines << "\t\tEnd: AWS - #{Colors.aws_changes(@aws.end_time)}, Local - #{Colors.local_changes(@local.end)}"
        when RECURRENCE
          diff_lines << "\t\tRecurrence: AWS - #{Colors.aws_changes(@aws.recurrence)}, Local - #{Colors.local_changes(@local.recurrence)}"
        when MIN
          diff_lines << "\t\tMin size: AWS - #{Colors.aws_changes(@aws.min_size)}, Local - #{Colors.local_changes(@local.min)}"
        when MAX
          diff_lines << "\t\tMax size: AWS - #{Colors.aws_changes(@aws.max_size)}, Local - #{Colors.local_changes(@local.max)}"
        when DESIRED
          diff_lines << "\t\tDesired capacity: AWS - #{Colors.aws_changes(@aws.desired_capacity)}, Local - #{Colors.local_changes(@local.desired)}"
        end

        diff_lines.flatten.join("\n")
      end

      def asset_type
        "Scheduled action"
      end

      def aws_name
        @aws.scheduled_action_name
      end
    end
  end
end
