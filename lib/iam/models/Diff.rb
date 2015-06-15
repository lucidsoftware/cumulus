require "util/Colors"

# Public: Enumeration of the types of changes that can be done to resources
module ChangeType
  ADD = 0
  REMOVE = 1
  CHANGE = 2
  REMOVE_POLICY = 3
end

# Public: Represents the differences between a local resource config and an AWS
# resource
class Diff

  attr_reader :name
  attr_accessor :type
  attr_reader :config

  # Public: Constructor
  #
  # name    - the name of the resource this diff is for
  # type    - the type of change this diff is for
  # config  - the resource configuration for the resource this diff is for
  def initialize(name, type, resource_type, config = nil)
    @name = name
    @policies = {}
    @type = type
    @config = config
    @resource_type = resource_type
  end

  # Public: Determine if there are differences between the resource config and
  # the AWS resource.
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
  # Returns the String representation of the resource differences
  def to_s
    if @type == ChangeType::ADD
      Colors.added("Add #{@resource_type} #{@name}")
    elsif @type == ChangeType::REMOVE
      Colors.unmanaged("AWS #{@resource_type} #{@name} is not managed by Cumulus")
    else
      ret = ["For #{@resource_type} #{@name} there are the following differences:"]
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
