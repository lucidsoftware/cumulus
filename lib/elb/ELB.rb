require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module ELB
    class << self
      @@client = Aws::ElasticLoadBalancing::Client.new(region: Configuration.instance.region)

      # Public: Static method that will get an ELB from AWS by its name.
      #
      # name - the name of the ELB to get
      #
      # Returns the Aws::ElasticLoadBalancing::Types::LoadBalancerDescription by that name
      def get_aws(name)
        if elbs[name].nil?
          puts "No ELB named #{name}"
          exit
        else
          elbs[name]
        end
      end

      # Public: Static method that will get an ELB from AWS by its dns name.
      #
      # dns_name - the dns name of the ELB to get
      #
      # Returns the Aws::ElasticLoadBalancing::Types::LoadBalancerDescription with that dns name
      def get_aws_by_dns_name(dns_name)
        elbs_to_dns_names[dns_name]
      end

      private

      # Internal: Provide a mapping of ELBs to their names. Lazily loads resources.
      #
      # Returns the ELBs mapped to their names
      def elbs
        @elbs ||= init_elbs
      end

      # Internal: Provide a mapping of ELBs to their dns names. Lazily loads resources.
      #
      # Returns the ELBs mapped to their dns names
      def elbs_to_dns_names
        @elbs_to_dns_names ||= Hash[elbs.map { |ignored, elb| [elb.dns_name, elb] }]
      end

      # Internal: Load ELBs and map them to their names.
      #
      # Returns the ELBs mapped to their names
      def init_elbs
        elbs = []
        all_records_retrieved = false
        next_marker = nil

        until all_records_retrieved
          response = @@client.describe_load_balancers({
            marker: next_marker
          }.reject { |k, v| v.nil? })

          elbs << response.load_balancer_descriptions
          next_marker = response.next_marker

          if next_marker == nil
            all_records_retrieved = true
          end
        end

        Hash[elbs.flatten.map { |elb| [elb.load_balancer_name, elb] }]
      end
    end
  end
end
