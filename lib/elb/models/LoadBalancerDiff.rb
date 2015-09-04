require "common/models/Diff"
require "common/models/ListChange"
require "elb/models/ListenerDiff"
require "util/Colors"

module Cumulus
  module ELB
    # Public: The types of changes that can be made to a load balancer
    module LoadBalancerChange
      include Common::DiffChange

      LISTENERS = Common::DiffChange.next_change_id
      SUBNETS = Common::DiffChange.next_change_id
      SECURITY = Common::DiffChange.next_change_id
      INTERNAL = Common::DiffChange.next_change_id
      TAGS = Common::DiffChange.next_change_id
      INSTANCES = Common::DiffChange.next_change_id
      HEALTH = Common::DiffChange.next_change_id
      BACKEND = Common::DiffChange.next_change_id
      CROSS = Common::DiffChange.next_change_id
      LOG = Common::DiffChange.next_change_id
      DRAINING = Common::DiffChange.next_change_id
      IDLE = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and
    # an AWS Load Balancer.
    class LoadBalancerDiff < Common::Diff
      include LoadBalancerChange

      attr_accessor :listeners
      attr_accessor :subnets
      attr_accessor :security_groups
      attr_accessor :tags
      attr_accessor :instances
      attr_accessor :health_diffs
      attr_accessor :backend_policies
      attr_accessor :log_diffs

      def self.listeners(aws, local)
        # map listeners to load balancer port
        aws_listeners = Hash[aws.map { |l| [l.listener.load_balancer_port, l] }]
        local_listeners = Hash[local.map { |l| [l.load_balancer_port, l] }]

        added_listeners = local_listeners.reject { |k, v| aws_listeners.has_key? k }
        removed_listeners = aws_listeners.reject { |k, v| local_listeners.has_key? k }
        modified_listeners = local_listeners.select { |k, v| aws_listeners.has_key? k }

        added_diffs = Hash[added_listeners.map { |port, added| [port, ListenerDiff.added(added)] }]
        removed_diffs = Hash[removed_listeners.map { |port, removed| [port, ListenerDiff.unmanaged(removed)] }]
        modified_diffs = Hash[modified_listeners.map do |port, modified|
          [port, modified.diff(aws_listeners[port])]
        end].reject { |k, v| v.empty? }

        if !added_diffs.empty? or !removed_diffs.empty? or !modified_diffs.empty?
          diff = LoadBalancerDiff.new(LISTENERS, aws, local)
          diff.listeners = Common::ListChange.new(added_diffs, removed_diffs, modified_diffs)
          diff
        end
      end

      def self.subnets(aws, local)
        local_ids = local.map { |s| s.subnet_id }
        aws_ids = aws.map { |s| s.subnet_id }

        added = local.reject { |s| aws_ids.include? s.subnet_id }
        removed = aws.reject { |s| local_ids.include? s.subnet_id }
        diff = LoadBalancerDiff.new(SUBNETS, aws, local)
        diff.subnets = Common::ListChange.new(added, removed)
        diff
      end

      def self.security_groups(aws, local)
        added = local - aws
        removed = aws - local
        diff = LoadBalancerDiff.new(SECURITY, aws, local)
        diff.security_groups = Common::ListChange.new(added, removed)
        diff
      end

      def self.internal(aws, local)
        LoadBalancerDiff.new(INTERNAL, aws, local)
      end

      TagChange = Struct.new(:key, :aws, :local)
      def self.tags(aws, local)
        added = []
        removed = []
        modified = []

        aws.each_pair do |key, val|
          if local.has_key?(key)
            if local[key] != val
              modified << TagChange.new(key, val, local[key])
            end
          else
            removed << TagChange.new(key, val, nil)
          end
        end

        local.each_pair do |key, val|
          if !aws.has_key?(key)
            added << TagChange.new(key, nil, val)
          end
        end

        diff = LoadBalancerDiff.new(TAGS, aws, local)
        diff.tags = Common::ListChange.new(added, removed, modified)
        diff
      end

      def self.instances(aws, local)
        added = local - aws
        removed = aws - local
        diff = LoadBalancerDiff.new(INSTANCES, aws, local)
        diff.instances = Common::ListChange.new(added, removed)
        diff
      end

      def self.health_check(health_diffs)
        diff = LoadBalancerDiff.new(HEALTH, nil, nil)
        diff.health_diffs = health_diffs
        diff
      end

      BackendChange = Struct.new(:port, :aws_policies, :local_policies)
      def self.backend_policies(aws, local)
        # map the aws and local policies to their ports
        aws_backends = Hash[aws.map { |b| [b.instance_port, b.policy_names] }]
        local_backends = Hash[local.map { |b| [b.instance_port, b.policy_names] }]

        added = local_backends.reject { |port, _| aws_backends.has_key? port }.to_a.map do |port, policies|
          BackendChange.new(port, nil, policies)
        end
        removed = aws_backends.reject { |port, _| local_backends.has_key? port }.to_a.map do |port, policies|
          BackendChange.new(port, policies, nil)
        end
        modified = local_backends.reject { |port, _| !aws_backends.has_key? port }.to_a.map do |port, policies|
          if aws_backends[port].sort != policies.sort
            BackendChange.new(port, aws_backends[port], policies)
          end
        end.reject(&:nil?)

        diff = LoadBalancerDiff.new(BACKEND, aws, local)
        diff.backend_policies = Common::ListChange.new(added, removed, modified)
        diff
      end

      def self.access_log(log_diffs)
        diff = LoadBalancerDiff.new(LOG, nil, nil)
        diff.log_diffs = log_diffs
        diff
      end

      def asset_type
        "Load Balancer"
      end

      def aws_name
        @aws.load_balancer_name
      end

      def diff_string
        case @type
        when LISTENERS
          [
            "listeners:",
            @listeners.removed.map { |_, diff| "\t#{diff}" },
            @listeners.added.map { |_, diff| "\t#{diff}" },
            @listeners.modified.map do |port, diffs|
              [
                "\tListener for port #{port}:",
                diffs.map do |diff|
                  diff.to_s.lines.map { |l| "\t\t#{l}".chomp("\n") }
                end
              ].join("\n")
            end
          ].flatten.join("\n")
        when SUBNETS
          [
            "subnets:",
            @subnets.removed.map { |s| Colors.removed("\t#{s.subnet_id} (#{s.name})") },
            @subnets.added.map { |s| Colors.added("\t#{s.subnet_id} (#{s.name})") },
          ].flatten.join("\n")
        when SECURITY
          [
            "security groups:",
            @security_groups.removed.map { |s| Colors.removed("\t#{s}") },
            @security_groups.added.map { |s| Colors.added("\t#{s}") },
          ].flatten.join("\n")
        when INTERNAL
          [
            "internal:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when TAGS
          [
            "tags:",
            @tags.removed.map { |t| Colors.removed("\t#{t.key}: #{t.aws}") },
            @tags.added.map { |t| Colors.added("\t#{t.key}: #{t.local}") },
            @tags.modified.map do |t|
              [
                "\t#{t.key}:",
                Colors.aws_changes("(AWS) #{t.aws}"),
                Colors.local_changes("(Local) #{t.local}")
              ].join(" ")
            end
          ].flatten.join("\n")
        when INSTANCES
          [
            "managed instances:",
            @instances.removed.map { |i| Colors.removed("\t#{i}") },
            @instances.added.map { |i| Colors.added("\t#{i}") },
          ].flatten.join("\n")
        when HEALTH
          [
            "health check:",
            @health_diffs.map do |d|
              d.to_s.lines.map { |l| "\t#{l}".chomp("\n") }
            end
          ].join("\n")
        when BACKEND
          [
            "backend policies:",
            @backend_policies.removed.map { |bc| Colors.removed("\tinstance port #{bc.port}: #{bc.aws_policies.join(" ")}") },
            @backend_policies.added.map { |bc| Colors.added("\tinstance port #{bc.port}: #{bc.local_policies.join(" ")}") },
            @backend_policies.modified.map do |bc|
              [
                "\tinstance port #{bc.port}:",
                (bc.aws_policies - bc.local_policies).map { |p| Colors.removed("#{p}") },
                (bc.local_policies - bc.aws_policies).map { |p| Colors.added("#{p}") },
              ].flatten.join(" ")
            end
          ].flatten.join("\n")
        when CROSS
          [
            "cross zone load balancing:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].flatten.join("\n")
        when LOG
          [
            "access log:",
            @log_diffs.map do |d|
              d.to_s.lines.map { |l| "\t#{l}".chomp("\n") }
            end
          ].join("\n")
        when DRAINING
          [
            "connection draining:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when IDLE
          [
            "idle timeout:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        end
      end
    end
  end
end
