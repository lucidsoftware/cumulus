require "autoscaling/loader/Loader"
require "autoscaling/models/AutoScalingDiff"

require "aws-sdk"

# Public: The main class for the AutoScaling management module
class AutoScaling

  # Public: Constructor. Initializes the AWS client.
  def initialize
    @aws = Aws::AutoScaling::Client.new(
      region: Configuration.instance.region
    )
  end

  # Public: Print a diff between local configuration and configuration in AWS
  def diff
    each_difference do |name, diffs|
      if diffs.size == 1 and (diffs[0].type == AutoScalingChange::ADD or
        diffs[0].type == AutoScalingChange::UNMANAGED)
        puts diffs[0]
      else
        puts "AutoScaling Group #{name} has the following changes:"
        diffs.each do |diff|
          diff_string = diff.to_s.lines.map {|s| "\t#{s}" }.join
          puts diff_string
        end
      end
    end
  end

  private

  # Internal: Loop through the differences between local configuration and AWS
  #
  # f - Will pass the name of the group and an array of AutoScalingDiffs
  #     to the block passed to this function
  def each_difference(&f)
    locals = Hash[Loader.groups.map { |local| [local.name, local] }]
    aws = Hash[aws_groups.map { |aws| [aws.auto_scaling_group_name, aws] }]

    aws.each do |name, group|
      f.call(name, [AutoScalingDiff.unmanaged(group)]) if !locals.include?(name)
    end
    locals.each do |name, group|
      if !aws.include?(name)
        f.call(name, [AutoScalingDiff.added(group)])
      else
        f.call(name, group.diff(aws[name]))
      end
    end
  end

  # Internal: Get the AutoScaling Groups currently defined in AWS
  #
  # Returns an array of AutoScaling Groups
  def aws_groups
    @aws_groups ||= @aws.describe_auto_scaling_groups.auto_scaling_groups
  end
end
