require "common/models/Diff"
require "common/models/ListChange"
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

      attr_accessor :items

      def self.items(added, removed, local)
        diff = OriginSslProtocolsDiff.new(ITEMS, nil, local)
        diff.items = Common::ListChange.new(added, removed)
        diff
      end

      def diff_string
        case @type
        when ITEMS
          [
            "items:",
            @items.removed.map { |removed| Colors.removed("\t#{removed}") },
            @items.added.map { |added| Colors.added("\t#{added}") },
          ].flatten.join("\n")
        end
      end
    end
  end
end
