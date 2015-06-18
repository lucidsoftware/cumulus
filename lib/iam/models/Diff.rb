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
  attr_reader :policies
  attr_reader :added_users
  attr_reader :removed_users
  attr_reader :attached_policies
  attr_reader :detached_policies

  # Public: Constructor
  #
  # name    - the name of the resource this diff is for
  # type    - the type of change this diff is for
  # config  - the resource configuration for the resource this diff is for
  def initialize(name, type, config = nil)
    @name = name
    @policies = {}
    @added_users = []
    @removed_users = []
    @attached_policies = []
    @detached_policies = []
    @type = type
    @config = config
  end

  # Public: Determine if there are differences between the resource config and
  # the AWS resource.
  #
  # Returns true if there are differences, false if there aren't
  def different?
    return (
      !@policies.empty? or
      !@added_users.empty? or
      !@removed_users.empty? or
      !@attached_policies.empty? or
      !@detached_policies.empty?
    )
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

  # Public: Add a user to the Diff. This only applies to GroupConfigs
  #
  # user - the user to add
  def add_user(user)
    @added_users << user
  end

  # Public: Remove a user from the Diff. This only applies to GroupConfigs
  #
  # user - the user to remove
  def remove_user(user)
    @removed_users << user
  end

  # Public: Attach a managed policy to the Diff.
  #
  # policy_arn - the arn of the policy to attach
  def attach_policy(arn)
    @attached_policies << arn
  end

  # Public: Detach a manager policy from the Diff
  #
  # policy_arn - the arn of the policy to detach
  def detach_policy(arn)
    @detached_policies << arn
  end

  # Public: to string
  #
  # Returns the String representation of the resource differences
  def to_s
    if @type == ChangeType::ADD
      @config.added_string
    elsif @type == ChangeType::REMOVE
      Colors.unmanaged("#{@name} is not managed by Cumulus")
    else
      @config.changed_string(self)
    end
  end

end
