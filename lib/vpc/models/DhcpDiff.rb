require "common/models/Diff"
require "common/models/ListChange"
require "util/Colors"

module Cumulus
  module VPC
    # Public: The types of changes that can be made to the dhcp configuration
    module DhcpChange
      include Common::DiffChange

      DOMAIN_SERVERS = Common::DiffChange.next_change_id
      DOMAIN_NAME = Common::DiffChange.next_change_id
      NTP_SERVERS = Common::DiffChange.next_change_id
      NETBIOS_SERVERS = Common::DiffChange.next_change_id
      NETBIOS_NODE = Common::DiffChange.next_change_id
    end

    # Public: Represents a single difference between local configuration and
    # an AWS Load Balancer.
    class DhcpDiff < Common::Diff
      include DhcpChange

      def self.domain_servers(aws, local)
        changes = Common::ListChange.simple_list_diff(aws, local)
        if changes
          diff = DhcpDiff.new(DOMAIN_SERVERS, aws, local)
          diff.changes = changes
          diff
        end
      end

      def self.ntp_servers(aws, local)
        changes = Common::ListChange.simple_list_diff(aws, local)
        if changes
          diff = DhcpDiff.new(NTP_SERVERS, aws, local)
          diff.changes = changes
          diff
        end
      end

      def self.netbios_servers(aws, local)
        changes = Common::ListChange.simple_list_diff(aws, local)
        if changes
          diff = DhcpDiff.new(NETBIOS_SERVERS, aws, local, servers_diff)
          diff.changes = changes
          diff
        end
      end

      def asset_type
        "DHCP Options"
      end

      def diff_string
        case @type
        when DOMAIN_SERVERS
          [
            "Domain Name Servers:",
            @changes.removed.map { |d| Colors.unmanaged("\t#{d}") },
            @changes.added.map { |d| Colors.added("\t#{d}") },
          ].flatten.join("\n")
        when DOMAIN_NAME
          [
            "Domain Name:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        when NTP_SERVERS
          [
            "NTP Servers:",
            @changes.removed.map { |n| Colors.unmanaged("\t#{n}") },
            @changes.added.map { |n| Colors.added("\t#{n}") },
          ].flatten.join("\n")
        when NETBIOS_SERVERS
          [
            "NETBIOS Name Servers:",
            @changes.removed.map { |n| Colors.unmanaged("\t#{n}") },
            @changes.added.map { |n| Colors.added("\t#{n}") },
          ].flatten.join("\n")
        when NETBIOS_NODE
          [
            "NETBIOS Node Type:",
            Colors.aws_changes("\tAWS - #{aws}"),
            Colors.local_changes("\tLocal - #{local}"),
          ].join("\n")
        end
      end
    end
  end
end
