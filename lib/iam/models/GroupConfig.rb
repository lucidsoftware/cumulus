require "iam/models/Diff"
require "iam/models/ResourceWithPolicy"
require "util/Colors"

# Public: Represents a config file for a group
class GroupConfig < ResourceWithPolicy

  attr_accessor :users

  # Public: Constructor
  #
  # json - the Hash containing the JSON configuration for this GroupConfig, if
  #        nil, this will be an "empty GroupConfig"
  def initialize(json = nil)
    super(json)
    @type = "group"
    @users = json["users"] unless json.nil?
  end

  # override diff to check for changes in users
  def diff(aws_resource)
    differences = super(aws_resource)

    aws_users = aws_resource.users.map { |user| user.name }
    new_users = @users.select { |local| !aws_users.include?(local) }
    unmanaged = aws_users.select { |aws| !@users.include?(aws) }

    if !unmanaged.empty? or !new_users.empty?
      differences.type = ChangeType::CHANGE
      new_users.each { |u| differences.add_user(u) }
      unmanaged.each { |u| differences.remove_user(u) }
    end

    differences
  end

  # override added_string to include the users that will be added
  def added_string
    lines = [super()]
    if !@users.empty?
      lines << Colors.added("\tThese users will be added to the group:")
      @users.each do |user|
        lines << Colors.added("\t\t#{user}")
      end
    end
    lines.join("\n")
  end

  # override changed_string to add the users that will be added or removed
  def changed_string(diff)
    lines = [super(diff)]

    if !diff.added_users.empty?
      lines << "\tAdding the following users:"
      lines << diff.added_users.map { |user| Colors.added("\t\t#{user}") }
    end

    if !diff.removed_users.empty?
      lines << "\tRemoving the following users:"
      lines << diff.removed_users.map { |user| Colors.unmanaged("\t\t#{user}") }
    end

    lines.flatten.join("\n")
  end

  def hash
    h = super()
    h["users"] = @users
    h
  end

end
