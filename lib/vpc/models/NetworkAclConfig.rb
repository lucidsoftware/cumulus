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
      # name - the name of the network acl config
      # json - a hash containing the JSON configuration for the Network ACL
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @inbound = (json["inbound"] || []).map { |entry| AclEntryConfig.new(entry) }
          @outbound = (json["outbound"] || []).map { |entry| AclEntryConfig.new(entry) }
          @tags = json["tags"] || {}
        end
      end

      def to_hash
        {
          "inbound" => @inbound.map(&:to_hash),
          "outbound" => @outbound.map(&:to_hash),
          "tags" => @tags
        }.reject { |k, v| v.nil? }
      end

      def populate!(aws)
        @inbound = aws.diffable_entries.select { |entry| !entry.egress }
                      .map { |entry| AclEntryConfig.new().populate!(entry) }
                      .sort_by!(&:rule)
        @outbound = aws.diffable_entries.select { |entry| entry.egress }
                      .map { |entry| AclEntryConfig.new().populate!(entry) }
                      .sort_by!(&:rule)
        @tags = Hash[aws.tags.map { |tag| [tag.key, tag.value] }]

        # If there is not a name then add a name tag using the given name
        if !@tags["Name"]
          puts "Network ACL #{aws.network_acl_id} does not have a Name defined. Cumulus will use #{name} as the name when migrated."
          @tags["Name"] = @name
        end

        self
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the NetworkAclDiffs that were found
      def diff(aws)
        diffs = []

        aws_inbound = aws.diffable_entries.select { |entry| !entry.egress }
        inbound_diff = NetworkAclDiff.entries(NetworkAclChange::INBOUND, aws_inbound, @inbound)
        if inbound_diff
          diffs << inbound_diff
        end

        aws_outbound = aws.diffable_entries.select { |entry| entry.egress }
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
