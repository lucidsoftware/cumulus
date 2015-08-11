require "util/Colors"

# Public: The types of changes common to all Diffs
module DiffChange
  @@current = 0

  # Public: Produce the next id for a change type. Use this to avoid id
  # collisions.
  #
  # Returns the new id
  def self.next_change_id
    @@current += 1
    @@current
  end

  ADD = next_change_id
  UNMANAGED = next_change_id

end

# Public: The base class for all Diff classes.
#
# To extend this class, do the following:
#
# 1. Provide a `diff_string` method. This method will be called if the default
#    to_s method cannot produce a result.
# 2. Provide a `asset_type` method. This method should return the string type of
#    asset for which this is a diff.
# 3. Provide an `aws_name` method. This method should give back the string name
#    of the aws asset.
class Diff
  include DiffChange

  attr_reader :aws, :local, :type

  # Public: Static method that will produce an "unmanaged" diff
  #
  # aws - the aws resource that is unmanaged
  #
  # Returns the diff
  def self.unmanaged(aws)
    self.new(UNMANAGED, aws)
  end

  # Public: Static method that will produce an "added" diff
  #
  # local - the local configuration that is added
  #
  # Returns the diff
  def self.added(local)
    self.new(ADD, nil, local)
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
      Colors.added("#{asset_type} #{@local.name} #{add_string}")
    when UNMANAGED
      Colors.unmanaged("#{asset_type} #{aws_name} is not managed by Cumulus.")
    else
      diff_string
    end
  end

  # Public: A method that produces the string that describes what will be done with new assets.
  # This can be overridden for the case that the ADD case doesn't create the asset.
  #
  # Returns the string describing the action that will be taken.
  def add_string
    "will be created."
  end
end