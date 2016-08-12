require "json"
require "deepsort"

module AwsExtensions
  module IAM
    module Policy
      def as_hash
        # Sort the statments to prevent false conflicts while diffing
        sorted_policy = JSON.parse(URI.unescape(policy_document)).deep_sort
        sorted_policy["Statement"].each do |statement|
          # actions sometimes contains a single string element instead of the expected array
          statement["Action"] = [statement["Action"]] if statement["Action"].is_a? String
          # resources sometimes contains a single string element instead of the expected array
          statement["Resource"] = [statement["Resource"]] if statement["Resource"].is_a? String
        end
        # return the sorted policy hash
        sorted_policy
      end
    end
  end
end

