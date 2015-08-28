require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

module Cumulus
  module S3
    # Public: The types of changes that can be made to a Grant
    module GrantChange
      include Common::DiffChange

      PERMISSIONS = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and
    # an AWS Grant.
    class GrantDiff < Common::Diff
      include GrantChange

      def initialize(type, aws = nil, local = nil)
        super(type, aws, local)

        if aws and local
          @permissions = Common::ListChange.new(
            local.permissions - aws.permissions,
            aws.permissions - local.permissions
          )
        end
      end

      def asset_type
        "Grant"
      end

      def aws_name
        @aws.name
      end

      def diff_string
        case @type
        when PERMISSIONS
          [
            "#{@local.name}:",
            @permissions.removed.map { |p| Colors.removed("\t#{p}") },
            @permissions.added.map { |p| Colors.added("\t#{p}") },
          ].flatten.join("\n")
        end
      end
    end
  end
end
