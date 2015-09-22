require "conf/Configuration"
require "vpc/models/AclEntryConfig"
require "ec2/EC2"

require "json"

module Cumulus
  module VPC

    # Public: An object representing configuration for a VPC Network ACL
    class NetworkAclConfig
      attr_reader :inbound
      attr_reader :outbound
      attr_reader :tags
      attr_reader :name

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the Network ACL
      def initialize(json = nil)
        if !json.nil?
          @inbound = (json["inbound"] || []).map { |entry| AclEntryConfig.new(entry) }
          @outbound = (json["outbound"] || []).map { |entry| AclEntryConfig.new(entry) }
          @tags = json["tags"] || {}
          @name = @tags["Name"]
        end
      end

      def to_hash
        {
          "inbound" => @inbound.map(&:to_hash),
          "outbound" => @outbound.map(&:to_hash),
          "tags" => @tags
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the NetworkAclDiffs that were found
      def diff(aws)
        diffs = []

        aws_inbound = aws.entries.select { |entry| !entry.egress }
        inbound_diff = NetworkAclDiff.entries(NetworkAclChange::INBOUND, aws_inbound, @inbound)
        if inbound_diff
          diffs << inbound_diff
        end

        aws_outbound = aws.entries.select { |entry| entry.egress }
        outbound_diff = NetworkAclDiff.entries(NetworkAclChange::OUTBOUND, aws_outbound, @outbound)
        if outbound_diff
          diffs << outbound_diff
        end

        aws_tags = Hash[aws.tags.map { |tag| [tag.key, tag.value] }]
        if @tags != aws_tags
          diffs << NetworkAclDiff.new(NetworkAclChange::TAGS, aws_tags, @tags)
        end

        diffs
      end

    end
  end
end
