require "elb/models/HealthCheckDiff"

require "json"

module Cumulus
  module ELB
    # Public: An object representing configuration for a load balancer
    class HealthCheckConfig
      attr_reader :target
      attr_reader :interval
      attr_reader :timeout
      attr_reader :healthy
      attr_reader :unhealthy

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the load balancer
      def initialize(json = nil)
        if !json.nil?
          @target = json["target"]
          @interval = json["interval"]
          @timeout = json["timeout"]
          @healthy = json["healthy"]
          @unhealthy = json["unhealthy"]
        end
      end

      def to_hash
        {
          "target" => @target,
          "interval" => @interval,
          "timeout" => @timeout,
          "healthy" => @healthy,
          "unhealthy" => @unhealthy,
        }.reject { |k, v| v.nil? }
      end

      def to_aws
        {
          target: @target,
          interval: @interval,
          timeout: @timeout,
          healthy_threshold: @healthy,
          unhealthy_threshold: @unhealthy,
        }
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the HealthCheckDiffs that were found
      def diff(aws)
        diffs = []

        if @target != aws.target
          diffs << HealthCheckDiff.new(HealthCheckChange::TARGET, aws.target, @target)
        end

        if @interval != aws.interval
          diffs << HealthCheckDiff.new(HealthCheckChange::INTERVAL, aws.interval, @interval)
        end

        if @timeout != aws.timeout
          diffs << HealthCheckDiff.new(HealthCheckChange::TIMEOUT, aws.timeout, @timeout)
        end

        if @healthy != aws.healthy_threshold
          diffs << HealthCheckDiff.new(HealthCheckChange::HEALTHY, aws.healthy_threshold, @healthy)
        end

        if @unhealthy != aws.unhealthy_threshold
          diffs << HealthCheckDiff.new(HealthCheckChange::UNHEALTHY, aws.unhealthy_threshold, @unhealthy)
        end

        diffs
      end


    end
  end
end
