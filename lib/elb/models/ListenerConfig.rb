require "elb/models/ListenerDiff"

require "json"

module Cumulus
  module ELB
    # Public: An object representing configuration for a listener
    class ListenerConfig
      attr_reader :load_balancer_protocol
      attr_reader :load_balancer_port
      attr_reader :instance_protocol
      attr_reader :instance_port
      attr_reader :ssl_certificate_id
      attr_reader :policies

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the listener
      def initialize(json = nil)
        if !json.nil?
          @load_balancer_protocol = json["load-balancer-protocol"]
          @load_balancer_port = json["load-balancer-port"]
          @instance_protocol = json["instance-protocol"]
          @instance_port = json["instance-port"]
          @ssl_certificate_id = json["ssl-certificate-id"]
          @policies = json["policies"] || []
        end
      end

      def to_hash
        {
          "load-balancer-protocol" => @load_balancer_protocol,
          "load-balancer-port" => @load_balancer_port,
          "instance-protocol" => @instance_protocol,
          "instance-port" => @instance_port,
          "ssl-certificate-id" => @ssl_certificate_id,
          "policies" => @policies,
        }.reject { |k, v| v.nil? }
      end

      def to_aws
        {
          protocol: @load_balancer_protocol,
          load_balancer_port: @load_balancer_port,
          instance_protocol: @instance_protocol,
          instance_port: @instance_port,
          ssl_certificate_id: @ssl_certificate_id,
        }.reject { |k, v| v.nil? }
      end

      def populate!(aws)
        @load_balancer_protocol = aws.listener.protocol
        @load_balancer_port = aws.listener.load_balancer_port
        @instance_protocol = aws.listener.instance_protocol
        @instance_port = aws.listener.instance_port
        @ssl_certificate_id = aws.listener.ssl_certificate_id
        @policies = aws.policy_names
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the ListenerDiffs that were found
      def diff(aws)
        diffs = []

        if @load_balancer_protocol != aws.listener.protocol
          diffs << ListenerDiff.new(ListenerChange::LB_PROTOCOL, aws.listener.protocol, @load_balancer_protocol)
        end

        if @load_balancer_port != aws.listener.load_balancer_port
          diffs << ListenerDiff.new(ListenerChange::LB_PORT, aws.listener.load_balancer_port, @load_balancer_port)
        end

        if @instance_protocol != aws.listener.instance_protocol
          diffs << ListenerDiff.new(ListenerChange::INST_PROTOCOL, aws.listener.instance_protocol, @instance_protocol)
        end

        if @instance_port != aws.listener.instance_port
          diffs << ListenerDiff.new(ListenerChange::INST_PORT, aws.listener.instance_port, @instance_port)
        end

        if @ssl_certificate_id != aws.listener.ssl_certificate_id
          diffs << ListenerDiff.new(ListenerChange::SSL, aws.listener.ssl_certificate_id, @ssl_certificate_id)
        end

        if @policies.sort != aws.policy_names.sort
          diffs << ListenerDiff.policies(aws.policy_names, @policies)
        end

        diffs
      end


    end
  end
end
