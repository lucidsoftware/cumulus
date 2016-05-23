require "cloudfront/models/OriginSslProtocolsDiff"

module Cumulus
  module CloudFront
    OriginSslProtocols = Struct.new(:items) do
      def quantity
        items && items.length || 0
      end

      def diff(aws)
        diffs = []

        aws_items = aws && aws.items || []
        added_items = self.items - aws_items
        removed_items = aws_items - self.items
        if !added_items.empty? || !removed_items.empty?
          diffs << OriginSslProtocolsDiff.items(added_items, removed_items, self)
        end

        diffs
      end

      def to_local
        self.items
      end
    end
  end
end
