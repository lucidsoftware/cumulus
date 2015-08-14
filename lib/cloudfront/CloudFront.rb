require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module CloudFront
    class << self
      @@client = Aws::CloudFront::Client.new(region: Configuration.instance.region)

      # Public: Static method that will get a distribution from AWS by its origin.
      #
      # origin - the origin of the distribution to get
      #
      # Returns the Aws::CloudFront::Types::DistributionSummary
      def get_aws(origin)
        distributions[origin]
      end

      private

      # Internal: Provide a mapping of CloudFront distributions to their origins. Lazily loads resources.
      #
      # Returns the distributions mapped to their origins
      def distributions
        @distributions ||= init_distributions
      end

      # Internal: Load the distributions and map them to their origins.
      #
      # Returns the distributions mapped to their origins
      def init_distributions
        distributions = []
        all_records_retrieved = false
        next_marker = nil;

        until all_records_retrieved
          response = @@client.list_distributions({
            marker: next_marker
          }.reject { |k, v| v.nil? })
          distributions << response.distribution_list.items
          next_marker = response.distribution_list.next_marker

          if !response.distribution_list.is_truncated
            all_records_retrieved = true
          end
        end

        Hash[distributions.flatten.flat_map do |dist|
          dist.aliases.items.map { |a| [a, dist] }
        end]
      end
    end
  end
end
