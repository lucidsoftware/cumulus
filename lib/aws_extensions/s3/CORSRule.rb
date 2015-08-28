require "aws-sdk"

module AwsExtensions
  module S3
    module CORSRule
      def to_s
        [
          "Origins: #{allowed_origins.join(",")}",
          "Methods: #{allowed_methods.join(", ")}",
          "Headers: #{allowed_headers.join(",")}",
          ("Exposed Headers: #{expose_headers.join(", ")}" unless expose_headers.empty?),
          "Max Age Seconds: #{max_age_seconds}"
        ].reject { |s| s.nil? }.join(", ")
      end
    end
  end
end
