require "common/models/Diff"
require "util/Colors"

# Public: Base class for AWS resource manager classes.
#
# Classes that extend this class should provide the following methods:
#
#   resource_name - return the resource name type (ie "Autoscaling Group", "Security Group", etc)
#   local_resources - return a Hash of local resource name to local resource config object
#   aws_resources - return a Hash of aws resource name to aws resource object
#   diff_resource - a function that will produce an array of differences between the local resource
#     passed in and the aws resource passed in
#   unmanaged_diff - return the correct type of diff from an AWS resource
#   added_diff - return the correct type of diff from a local configuration object
#   create - given a local configuration, create the AWS resource
#   update - given a local configuration and an array of diffs, update the AWS resource
class Manager
  def initialize
    @migration_root = "generated"
  end

  # Public: Print a diff between local configuration and configuration in AWS
  def diff
    each_difference(local_resources, true) { |name, diffs| print_difference(name, diffs) }
  end

  # Public: Print the diff between local configuration and AWS for a single resource
  #
  # name - the name of the resource to diff
  def diff_one(name)
    local = local_resources.reject { |n, l| n != name }
    each_difference(local, false) { |name, diffs| print_difference(name, diffs) }
  end

  # Public: Print out the names of all resources managed by Cumulus
  def list
    puts local_resources.map { |name, l| name }.join(" ")
  end

  # Public: Sync local configuration to AWS
  def sync
    each_difference(local_resources, true) { |name, diffs| sync_difference(name, diffs) }
  end

  # Public: Sync local configuration to AWS for a single resource
  #
  # name - the name of the resource to sync
  def sync_one(name)
    local = local_resources.reject { |n, l| n != name }
    each_difference(local, false) { |name, diffs| sync_difference(name, diffs) }
  end

  private

  # Internal: Loop through the differences between local configuration and AWS
  #
  # locals            - the local configurations to compare against
  # include_unmanaged - whether to include unmanaged resources in the list of changes
  # f                 - a function that will be passed the name of the resource and an array of
  #                     diffs
  def each_difference(locals, include_unmanaged, &f)
    if include_unmanaged
      aws_resources.each do |name, resource|
        f.call(name, [unmanaged_diff(resource)]) if !local_resources.include?(name)
      end
    end
    local_resources.each do |name, resource|
      if !aws_resources.include?(name)
        f.call(name, [added_diff(resource)])
      else
        f.call(name, diff_resource(resource, aws_resources[name]))
      end
    end
  end

  # Internal: Print differences.
  #
  # name  - the name of the resource to print
  # diffs - the differences between local configuration and AWS
  def print_difference(name, diffs)
    if diffs.size > 0
      if diffs.size == 1 and (diffs[0].type == DiffChange::ADD or
        diffs[0].type == DiffChange::UNMANAGED)
        puts diffs[0]
      else
        puts "#{resource_name} #{name} has the following changes:"
        diffs.each do |diff|
          diff_string = diff.to_s.lines.map { |s| "\t#{s}" }.join
          puts diff_string
        end
      end
    end
  end

  # Internal: Sync differences.
  #
  # name  - the name of the resource to sync
  # diffs - the differences between local configuration and AWS
  def sync_difference(name, diffs)
    if diffs.size > 0
      if diffs[0].type == DiffChange::UNMANAGED
        puts diffs[0]
      elsif diffs[0].type == DiffChange::ADD
        puts Colors.added("creating #{name}...")
        create(diffs[0].local)
      else
        puts Colors.blue("updating #{name}...")
        update(diffs[0].local, diffs)
      end
    end
  end
end
