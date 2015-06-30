require "util/Colors"

# Public: The types of changes that can be made to scaling policies
module PolicyChange
  ADD = 1
  UNMANAGED = 2
  ADJUSTMENT_TYPE = 3
  ADJUSTMENT = 4
  COOLDOWN = 5
  MIN_ADJUSTMENT = 6
end

# Public: Represents a single difference between local configuration and AWS
# configuration of scaling policies
class PolicyDiff
  include PolicyChange

  attr_reader :aws, :local, :type

  # Public: Static method that will produce an "unmanaged" diff
  #
  # aws - the aws resource that is unmanaged
  #
  # Returns the diff
  def PolicyDiff.unmanaged(aws)
    PolicyDiff.new(UNMANAGED, aws)
  end

  # Public: Static method that will produce an "added" diff
  #
  # local - the local configuration that is added
  #
  # Returns the diff
  def PolicyDiff.added(local)
    PolicyDiff.new(ADD, nil, local)
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
      Colors.added("Scaling policy #{@local.name} will be created.")
    when UNMANAGED
      Colors.unmanaged("Scaling policy #{@aws.policy_name} is not managed by Cumulus.")
    when ADJUSTMENT_TYPE
      "Adjustment type: AWS - #{Colors.aws_changes(@aws.adjustment_type)}, Local - #{Colors.local_changes(@local.adjustment_type)}"
    when ADJUSTMENT
      "Scaling adjustment: AWS - #{Colors.aws_changes(@aws.scaling_adjustment)}, Local - #{Colors.local_changes(@local.adjustment)}"
    when COOLDOWN
      "Cooldown: AWS - #{Colors.aws_changes(@aws.cooldown)}, Local - #{Colors.local_changes(@local.cooldown)}"
    when MIN_ADJUSTMENT
      "Min adjustment step: AWS - #{Colors.aws_chnages(@aws.min_adjustment_step)}, Local - #{Colors.local_changes(@local.min_adjustment)}"
    end
  end

end
