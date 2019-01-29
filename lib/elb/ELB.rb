require "conf/Configuration"

require "aws-sdk-elasticloadbalancing"

module Cumulus
  module ELB
    class << self
      @@client = Aws::ElasticLoadBalancing::Client.new(Configuration.instance.client)

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

      # Public: Provide a mapping of ELBs to their names. Lazily loads resources.
      #
      # Returns the ELBs mapped to their names
      def elbs
        @elbs ||= init_elbs
      end

      # Public: Provide the tags for an ELB by name
      #
      # Returns an array of Aws::ElasticLoadBalancing::Types::Tag
      def elb_tags(elb_name)
        @elb_tags ||= init_elb_tags

        @elb_tags[elb_name]
      end

      # Public: Provide the attributes for an ELB by name, lazily loaded
      #
      # Returns an array of Aws::ElasticLoadBalancing::Types::LoadBalancerAttributes
      def elb_attributes(elb_name)
        @elb_attributes ||= {}
        @elb_attributes[elb_name] ||= init_elb_attributes(elb_name)
      end

      # Public: Provide the default available policies
      #
      # Returns a Hash of Aws::ElasticLoadBalancing::Types::PolicyDescription to a policy's name
      def default_policies
        @default_policies ||= Hash[init_default_policies.map { |policy| [policy.policy_name, policy] }]
      end

      # Public: Provide the policies already created on a load balancer
      #
      # Returns a Hash of Aws::ElasticLoadBalancing::Types::PolicyDescription to a policy's name
      def elb_policies(elb_name)
        @elb_policies ||= {}
        @elb_policies[elb_name] ||= Hash[init_elb_policies(elb_name).map { |policy| [policy.policy_name, policy] }]
      end

      private

      # Internal: Provide a mapping of ELBs to their dns names. Lazily loads resources.
      #
      # Returns the ELBs mapped to their dns names
      def elbs_to_dns_names
        @elbs_to_dns_names ||= Hash[elbs.map { |_, elb| [elb.dns_name, elb] }]
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

      # Internal: Load ELB tags and map them to their names
      #
      # Returns the ELB tags mapped to ELB name
      def init_elb_tags
        tags = []
        elbs.keys.each_slice(20) do |names|
          tags << @@client.describe_tags({
            load_balancer_names: names
          }).tag_descriptions
        end

        Hash[tags.flatten.map { |td| [td.load_balancer_name, td.tags] }]
      end

      # Internal: Load ELB attributes for an ELB
      #
      # elb_name - the name of the ELB to get attributes for
      #
      # Returns the ELB attributes
      def init_elb_attributes(elb_name)
        @@client.describe_load_balancer_attributes({
          load_balancer_name: elb_name
        }).load_balancer_attributes
      end

      # Internal: Load the default ELB policies
      #
      # Returns an array of Aws::ElasticLoadBalancing::Types::PolicyDescription
      def init_default_policies
        @@client.describe_load_balancer_policies.policy_descriptions
      end

      # Internal: Load the policies for a load balancer
      #
      # Returns an array of Aws::ElasticLoadBalancing::Types::PolicyDescription
      def init_elb_policies(elb_name)
        @@client.describe_load_balancer_policies({
          load_balancer_name: elb_name
        }).policy_descriptions
      end

    end
  end
end
