require "common/models/Diff"
require "util/Colors"

module Cumulus
  module CloudFront
    # Public: The types of changes that can be made to origin ssl protocols
    module OriginSslProtocolsChange
      include Common::DiffChange

      ITEMS = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of origin ssl protocols
    class OriginSslProtocolsDiff < Common::Diff
      include OriginSslProtocolsChange

      attr_accessor :added_items
      attr_accessor :removed_items

      def self.items(added, removed, local)
        diff = OriginSslProtocolsDiff.new(ITEMS, nil, local)
        diff.added_items = added
        diff.removed_items = removed
        diff
      end

      def diff_string
        case @type
        when ITEMS
          [
            "items:",
            @removed_items.map { |removed| Colors.removed("\t#{removed}") },
            @added_items.map { |added| Colors.added("\t#{added}") },
          ].flatten.join("\n")
        end
      end
    end
  end
end
