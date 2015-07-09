require "common/models/Diff"
require "util/Colors"

require "json"

# Public: The types of changes that can be made to IAM resources
module IamChange
  include DiffChange

  ADDED_POLICY = DiffChange::next_change_id
  ATTACHED = DiffChange::next_change_id
  POLICY = DiffChange::next_change_id
  POLICY_DOC = DiffChange::next_change_id
  UNMANAGED_POLICY = DiffChange::next_change_id
  USER = DiffChange::next_change_id
end

# Public: Represents a single difference between local configuration and AWS
# configuration of an IAM resource
class IamDiff < Diff
  include IamChange

  attr_accessor :added_users
  attr_accessor :attached
  attr_accessor :policy_name
  attr_accessor :removed_users
  attr_accessor :detached

  # Public: Create an IamDiff that represents an unmanaged policy
  #
  # policy_name - the name of the policy that is unmanaged
  #
  # Returns an IamDiff representing the changes
  def self.unmanaged_policy(policy_name)
    diff = IamDiff.new(UNMANAGED_POLICY)
    diff.policy_name = policy_name
    diff
  end

  # Public: Create an IamDiff that represents an added policy
  #
  # policy_name - the name of the policy that is added
  # config      - the configuration for the policy
  #
  # Returns an IamDiff representing the changes
  def self.added_policy(policy_name, config)
    diff = IamDiff.new(ADDED_POLICY, nil, config)
    diff.policy_name = policy_name
    diff
  end

  # Public: Create an IamDiff to represent the changes in users for an IAM group
  #
  # added   - the added users
  # removed - the removed users
  #
  # Returns an IamDiff representing those changes
  def self.users(added, removed)
    diff = IamDiff.new(USER)
    diff.added_users = added
    diff.removed_users = removed
    diff
  end

  # Public: Create an IamDiff to represent changes in attached policies
  #
  # added   - the added attached policies
  # removed - the removed attached policies
  #
  # Returns an IamDiff representing those changes
  def self.attached(added, removed)
    diff = IamDiff.new(ATTACHED)
    diff.attached = added
    diff.detached = removed
    diff
  end

  def diff_string
    case @type
    when ADDED_POLICY
      Colors.added("Policy #{@policy_name} will be created.")
    when ATTACHED
      lines = ["Attached policies:"]
      lines << @attached.map { |arn| Colors.added("\t#{arn}") }
      lines << @detached.map { |arn| Colors.removed("\t#{arn}") }
      lines.flatten.join("\n")
    when POLICY
      lines = ["Policy differences:"]
      locals = @local.as_hash["Statement"]

      @aws.each do |aws|
        if !locals.include?(aws)
          lines << "\tAWS:\t#{Colors.aws_changes(aws.to_json)}"
        end
      end

      locals.each do |local|
        if !@aws.include?(local)
          lines << "\tLocal:\t#{Colors.local_changes(local.to_json)}"
        end
      end

      lines.join("\n")
    when POLICY_DOC
      aws = JSON.parse(URI.unescape(@aws.assume_role_policy_document)).to_s
      [
        "Assume role policy document:",
        Colors.aws_changes("\tAWS -\t#{aws}"),
        Colors.local_changes("\tLocal -\t#{@local.one_line_policy_document}")
      ].join("\n")
    when UNMANAGED_POLICY
      Colors.unmanaged("Policy #{@policy_name} is not managed by Cumulus")
    when USER
      lines = ["User differences:"]
      lines << @added_users.map { |u| Colors.added("\t#{u}") }
      lines << @removed_users.map { |u| Colors.removed("\t#{u}") }
      lines.flatten.join("\n")
    end
  end

  def asset_type
    "IAM resource"
  end

  def aws_name
    @aws.name
  end
end
