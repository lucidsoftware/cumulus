require "conf/Configuration"
require "elb/models/LoadBalancerDiff"
require "elb/models/ListenerConfig"
require "elb/models/HealthCheckConfig"
require "elb/models/AccessLogConfig"
require "elb/loader/Loader"
require "elb/ELB"
require "ec2/EC2"
require "security/SecurityGroups"

require "json"

module Cumulus
  module ELB

    # Public: An object representing configuration for a load balancer
    class LoadBalancerConfig
      attr_reader :name
      attr_reader :listeners
      attr_reader :availability_zones
      attr_reader :subnets
      attr_reader :security_groups
      attr_reader :internal
      attr_reader :tags
      attr_reader :manage_instances
      attr_reader :health_check
      attr_reader :cross_zone
      attr_reader :access_log
      attr_reader :connection_draining
      attr_reader :idle_timeout
      attr_reader :backend_policies

      require "aws_extensions/elb/BackendServerDescription"
      Aws::ElasticLoadBalancing::Types::BackendServerDescription.send(:include, AwsExtensions::ELB::BackendServerDescription)

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the load balancer
      def initialize(name, json = nil)
        @name = name
        if !json.nil?

          # load the included listeners and templates
          @listeners = []
          if json["listeners"]
            if json["listeners"]["includes"]
              json["listeners"]["includes"].each do |template_json|
                @listeners << Loader.listener(template_json["template"], template_json["vars"])
              end
            end
            if json["listeners"]["inlines"]
              json["listeners"]["inlines"].each do |inline|
                @listeners << ListenerConfig.new(inline)
              end
            end
          end

          # Map subnets to their actual subnet description from aws
          @subnets = (json["subnets"] || []).map do |subnet|
            full_subnet = EC2::named_subnets[subnet]

            if full_subnet.nil?
              raise "#{subnet} is not a valid subnet name or id"
            else
              full_subnet
            end
          end

          # Map backend policies to the Aws::ElasticLoadBalancing::Types::BackendServerDescription
          # reject any local polices with empty policies array which means it should be deleted from aws
          @backend_policies = (json["backend-policies"] || []).map do |backend|
            Aws::ElasticLoadBalancing::Types::BackendServerDescription.new({
              instance_port: backend["port"],
              policy_names: backend["policies"]
            })
          end.reject { |backend| backend.policy_names.empty? }

          @security_groups = json["security-groups"] || []
          @internal = json["internal"] || false
          @tags = json["tags"] || {}
          @manage_instances = json["manage-instances"] || false
          @health_check = if json["health-check"] then HealthCheckConfig.new(json["health-check"]) end
          @cross_zone = json["cross-zone"] || false
          @access_log = if json["access-log"] then AccessLogConfig.new(json["access-log"]) else false end
          @connection_draining = json["connection-draining"] || false
          @idle_timeout = json["idle-timeout"]
        end
      end

      # Public: Get the config as a prettified JSON string.
      #
      # Returns the JSON string
      def pretty_json
        JSON.pretty_generate({
          "listeners" => {
            "includes" => [],
            "inlines" => @listeners.map(&:to_hash)
          },
          "subnets" => @subnets,
          "security-groups" => @security_groups,
          "internal" => @internal,
          "tags" => @tags,
          "manage-instances" => @manage_instances,
          "health-check" => @health_check.to_hash,
          "backend-policies" => @backend_policies.map do |backend_policy|
            {
              "port" => backend_policy.instance_port,
              "policies" => backend_policy.policy_names
            }
          end,
          "cross-zone" => @cross_zone,
          "access-log" => if @access_log then @access_log.to_hash else @access_log end,
          "connection-draining" => @connection_draining,
          "idle-timeout" => @idle_timeout,
        })
      end

      # Public: populates the fields of a LoadBalancerConfig from AWS config
      #
      # aws_elb - the elb
      def populate!(aws_elb, aws_tags, aws_attributes)
        @listeners = aws_elb.listener_descriptions.map do |l|
          config = ListenerConfig.new
          config.populate!(l)
          config
        end
        @subnets = aws_elb.subnets.map do |subnet_id|
          EC2::id_subnets[subnet_id].name || subnet_id
        end
        @security_groups = aws_elb.security_groups.map do |sg_id|
            SecurityGroups::id_security_groups[sg_id].group_name
        end
        @internal = aws_elb.scheme == "internal"
        @tags = Hash[aws_tags.map do |tag|
          [tag.key, tag.value]
        end]
        @manage_instances = aws_elb.instances.map { |i| i.instance_id }
        @health_check = HealthCheckConfig.new
        @health_check.populate!(aws_elb.health_check)
        @backend_policies = aws_elb.backend_server_descriptions
        @cross_zone = aws_attributes.cross_zone_load_balancing.enabled
        @access_log = AccessLogConfig.new
        @access_log.populate!(aws_attributes.access_log)
        @connection_draining = aws_attributes.connection_draining.enabled && aws_attributes.connection_draining.timeout
        @idle_timeout = aws_attributes.connection_settings.idle_timeout
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the LoadBalancerDiffs that were found
      def diff(aws)
        diffs = []

        listener_diff = LoadBalancerDiff.listeners(aws.listener_descriptions, @listeners)
        if listener_diff
          diffs << listener_diff
        end

        aws_subnets = aws.subnets.map { |subnet_id| EC2::id_subnets[subnet_id] }
        if @subnets.sort != aws_subnets.sort
          diffs << LoadBalancerDiff.subnets(aws_subnets, @subnets)
        end

        named_aws_security_groups = aws.security_groups.map do |sg_id|
          SecurityGroups::id_security_groups[sg_id].group_name
        end
        if @security_groups.sort != named_aws_security_groups.sort
          diffs << LoadBalancerDiff.security_groups(named_aws_security_groups, @security_groups)
        end

        aws_internal = (aws.scheme == "internal")
        if @internal != aws_internal
          diffs << LoadBalancerDiff.internal(aws_internal, @internal)
        end

        aws_tags = Hash[ELB::elb_tags(@name).map { |tag| [tag.key, tag.value] }]
        if @tags != aws_tags
          diffs << LoadBalancerDiff.tags(aws_tags, @tags)
        end

        aws_instances = (aws.instances || []).map { |i| i.instance_id }
        if (@manage_instances != false) && @manage_instances.sort != aws_instances.sort
          diffs << LoadBalancerDiff.instances(aws_instances, @manage_instances)
        end

        aws_health_check = aws.health_check
        health_diffs = @health_check.diff(aws_health_check)
        if !health_diffs.empty?
          diffs << LoadBalancerDiff.health_check(health_diffs)
        end

        aws_backend_policies = aws.backend_server_descriptions
        if @backend_policies.sort != aws_backend_policies.sort
          diffs << LoadBalancerDiff.backend_policies(aws_backend_policies, @backend_policies)
        end

        aws_attributes = ELB::elb_attributes(@name)

        aws_cross_zone = (aws_attributes.cross_zone_load_balancing.enabled) rescue false
        if @cross_zone != aws_cross_zone
          diffs << LoadBalancerDiff.new(LoadBalancerChange::CROSS, aws_cross_zone, @cross_zone)
        end

        aws_access_log = aws_attributes.access_log
        if @access_log == false
          if aws_access_log.enabled == true
            log_diffs = (AccessLogConfig.new).diff(aws_access_log)
            diffs << LoadBalancerDiff.access_log(log_diffs)
          end
        else
          log_diffs = @access_log.diff(aws_access_log)
          if !log_diffs.empty?
            diffs << LoadBalancerDiff.access_log(log_diffs)
          end
        end

        aws_connection_draining = if aws_attributes.connection_draining.enabled then aws_attributes.connection_draining.timeout else false end
        if @connection_draining != aws_connection_draining
          diffs << LoadBalancerDiff.new(LoadBalancerChange::DRAINING, aws_connection_draining, @connection_draining)
        end

        aws_idle_timeout = aws_attributes.connection_settings.idle_timeout
        if @idle_timeout != aws_idle_timeout
          diffs << LoadBalancerDiff.new(LoadBalancerChange::IDLE, aws_idle_timeout, @idle_timeout)
        end

        diffs.flatten
      end

    end
  end
end
