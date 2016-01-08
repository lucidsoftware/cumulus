require "common/models/Diff"
require "util/Colors"
require "util/StatusCodes"

module Cumulus
  module Common
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
    #
    # Additionally, the following instance variables can be set to change the behavior of the manager:
    #
    #   create_asset - if true, the asset will be created, if false, a warning will be printed about
    #     the asset not being created
    class Manager
      def initialize
        @migration_root = "generated"
        @create_asset = true
      end

      # Public: Print a diff between local configuration and configuration in AWS
      def diff
        each_difference(local_resources, true) { |key, diffs| print_difference(key, diffs) }
      end

      # Public: Print the diff between local configuration and AWS for a single resource
      #
      # name - the name of the resource to diff
      def diff_one(name)
        each_difference(filter_local(name), false) { |key, diffs| print_difference(key, diffs) }
      end

      # Public: Print out the names of all resources managed by Cumulus
      def list
        puts local_resources.map { |key, l| l.name }.join(" ")
      end

      # Public: Sync local configuration to AWS
      def sync
        each_difference(local_resources, true) { |key, diffs| sync_difference(key, diffs) }
      end

      # Public: Sync local configuration to AWS for a single resource
      #
      # name - the name of the resource to sync
      def sync_one(name)
        each_difference(filter_local(name), false) { |key, diffs| sync_difference(key, diffs) }
      end

      # Public: Select local resources based on name
      def filter_local(name)
        local_resources.reject { |key, l| l.name != name }
      end

      private

      # Internal: Loop through the differences between local configuration and AWS
      #
      # locals            - the local configurations to compare against
      # include_unmanaged - whether to include unmanaged resources in the list of changes
      # f                 - a function that will be passed the name of the resource and an array of
      #                     diffs
      def each_difference(locals, include_unmanaged, &f)

        unmanaged = if include_unmanaged
          Hash[aws_resources.map do |key, resource|
            [key, [unmanaged_diff(resource)]] if !locals.include?(key)
          end.compact]
        else
          {}
        end

        managed = Hash[locals.map do |key, resource|
          if !aws_resources.include?(key)
            [key, [added_diff(resource)]]
          else
            [key, diff_resource(resource, aws_resources[key])]
          end
        end]

        combined = unmanaged.merge(managed)
        sorted_keys = combined.keys.sort
        sorted_keys.each do |key|
          f.call(key, combined[key])
        end
      end

      # Internal: Print differences.
      #
      # key   - the name of the resource to print
      # diffs - the differences between local configuration and AWS
      def print_difference(key, diffs)
        if diffs.size > 0

          if diffs.reject(&:info_only).size > 0
            StatusCodes::set_status(StatusCodes::DIFFS)
          end

          if diffs.size == 1 and (diffs[0].type == DiffChange::ADD or
            diffs[0].type == DiffChange::UNMANAGED)
            puts diffs[0]
          else
            puts "#{resource_name} #{local_resources[key].name} has the following changes:"
            diffs.each do |diff|
              diff_string = diff.to_s.lines.map { |s| "\t#{s}" }.join
              puts diff_string
            end
          end
        end
      end

      # Internal: Sync differences.
      #
      # key   - the name of the resource to sync
      # diffs - the differences between local configuration and AWS
      def sync_difference(key, diffs)
        if diffs.size > 0

          StatusCodes::set_status(StatusCodes::SYNC_DIFFS)

          if diffs[0].type == DiffChange::UNMANAGED
            puts diffs[0]
          elsif diffs[0].type == DiffChange::ADD
            if @create_asset
              puts Colors.added("creating #{local_resources[key].name}...")
              create(local_resources[key])
            else
              puts "not creating #{local_resources[key].name}..."
            end
          else
            puts Colors.blue("updating #{local_resources[key].name}...")
            update(local_resources[key], diffs)
          end
        end
      end
    end
  end
end
