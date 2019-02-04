require "common/BaseLoader"
require "conf/Configuration"
require "elb/models/LoadBalancerConfig"
require "elb/models/ListenerConfig"

require "aws-sdk-elasticloadbalancing"

# Public: Load ELB assets
module Cumulus
  module ELB
    module Loader
      include Common::BaseLoader

      @@elbs_dir = Configuration.instance.elb.load_balancers_directory
      @@listeners_dir = Configuration.instance.elb.listeners_directory
      @@policies_dir = Configuration.instance.elb.policies_directory

      # Public: Load all the load balancer configurations as LoadBalancerConfig objects
      #
      # Returns an array of LoadBalancerConfig
      def self.elbs
        Common::BaseLoader::resources(@@elbs_dir, &LoadBalancerConfig.method(:new))
      end

      # Public: Load a specified listener template by name, applying any variables
      #
      # name - the name of the listener template to load
      # vars - the hash of vars to apply
      #
      # returns
      def self.listener(name, vars)
        Common::BaseLoader.template(
          name,
          @@listeners_dir,
          vars,
          &proc do |_, json|
            ListenerConfig.new(json)
          end
        )
      end

      # Public: Load the specified user defined policy as an AWS policy
      #
      # Returns an Aws::ElasticLoadBalancing::Types::PolicyDescription
      def self.policy(policy_name)
        Common::BaseLoader::resource(policy_name, @@policies_dir) do |policy_name, policy|
          Aws::ElasticLoadBalancing::Types::PolicyDescription.new({
            policy_name: policy_name,
            policy_type_name: policy.fetch("type"),
            policy_attribute_descriptions: policy.fetch("attributes").map do |key, value|
              Aws::ElasticLoadBalancing::Types::PolicyAttributeDescription.new({
                attribute_name: key,
                attribute_value: value
              })
            end
          })
        end
      rescue KeyError
        puts "policy configuration #{policy_name} does not contain all required keys `type` and `attributes`"
        exit
      end

    end
  end
end
