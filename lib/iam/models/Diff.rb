require "util/Colors"

# Public: Enumeration of the types of changes that can be done to roles
module ChangeType
  ADD = 0
  REMOVE = 1
  CHANGE = 2
  REMOVE_POLICY = 3
end

# Public: Represents the differences between a local role config and an AWS
# Role
class Diff

  attr_reader :role
  attr_accessor :type
  attr_reader :config

  # Public: Constructor
  #
  # role    - the name of the role this diff is for
  # type    - the type of change this diff is for
  # config  - the RoleConfig for the for this diff is for
  def initialize(role, type, config = nil)
    @role = role
    @policies = {}
    @type = type
    @config = config
  end

  # Public: Determine if there are differences between the role config and
  # the AWS role.
  #
  # Returns true if there are differences, false if there aren't
  def different?
    return !@policies.empty?
  end

  # Public: Add a policy difference
  #
  # name        - the name of the policy that is different
  # difference  - a String representing the difference
  def add_diff(name, difference)
    if !@policies.key?(name)
      @policies[name] = []
    end
    @policies[name] << difference
  end

  # Public: to string
  #
  # Returns the String representation of the role differences
  def to_s
    if @type == ChangeType::ADD
      Colors.added_role("Add role #{@role}")
    elsif @type == ChangeType::REMOVE
      Colors.unmanaged_role("AWS role #{@role} is not managed by Cumulus")
    else
      ret = ["For role #{@role} there are the following differences:"]
      ret << @policies.map do |key, value|
        policy_diffs = ["\tIn policy #{key}:"]
        policy_diffs << value.map do |s|
          "\t\t#{s}"
        end
      end
      ret.join("\n")
    end
  end

end
