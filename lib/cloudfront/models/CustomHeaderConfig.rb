require 'cloudfront/models/CustomHeaderDiff'

module Cumulus
  module CloudFront
    CustomHeaderConfig = Struct.new(:name, :value) do
      def diff(aws)
        diffs = []

        aws_name = aws && aws.header_name
        if self.name != aws_name
          diffs << CustomHeaderDiff.new(CustomHeaderDiff::NAME, aws, self)
        end

        aws_value = aws && aws.header_value
        if self.value != aws_value
          diffs << CustomHeaderDiff.new(CustomHeaderDiff::VALUE, aws, self)
        end

        diffs
      end

      def to_aws
        {
          header_name: self.name,
          header_value: self.value
        }
      end
    end
  end
end
