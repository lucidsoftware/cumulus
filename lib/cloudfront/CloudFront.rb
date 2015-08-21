require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module CloudFront
    class << self
      @@client = Aws::CloudFront::Client.new(region: Configuration.instance.region)

      # Public: Static method that will get a distribution from AWS by its cname.
      #
      # cname - the cname of the distribution to get
      #
      # Returns the Aws::CloudFront::Types::DistributionSummary
      def get_aws(cname)
        if cname_distributions[cname].nil?
          puts "No CloudFront distribution named #{cname}"
          exit
        else
          cname_distributions[cname]
        end
      end

      # Public: Provides a mapping of cloudfront distributions to their id. Lazily loads resources.
      #
      # Returns the distributions mapped to their ids
      def id_distributions
        Hash[distributions.flatten.map { |dist| [dist.id, dist] }]
      end

      private

      # Internal: Provide a mapping of CloudFront distributions to their cnames. Lazily loads resources.
      #           Distributions without cnames are not included
      #
      # Returns the distributions mapped to their cnames
      def cname_distributions
        Hash[distributions.flat_map do |dist|
          dist.aliases.items.map { |a| [a, dist] }
        end]
      end

      # Internal: Provides a list of cloudfront distributions. Lazily loads resources.
      #
      # Returns the distributions
      def distributions
        @distributions ||= init_distributions
      end

      # Internal: Load the distributions and map them to their cnames.
      #
      # Returns the distributions mapped to their cnames
      def init_distributions
        distributions = []
        all_records_retrieved = false
        next_marker = nil

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

        distributions.flatten
      end
    end
  end
end
