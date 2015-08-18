require "conf/Configuration"
require "route53/models/RecordConfig"
require "route53/models/RecordDiff"
require "route53/models/Vpc"
require "route53/models/ZoneDiff"

require "json"

module Cumulus
  module Route53
    # Public: An object representing configuration for a zone
    class ZoneConfig
      attr_reader :comment
      attr_reader :domain
      attr_reader :id
      attr_reader :name
      attr_reader :private
      attr_reader :records
      attr_reader :vpc

      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the zone
      def initialize(name, json = nil)
        @name = name
        if !json.nil?
          @id = "/hostedzone/#{json["zone-id"]}"
          @domain = json["domain"].chomp(".")
          @private = json["private"]
          @vpc = if @private then json["vpc"].map { |v| Vpc.new(v["id"], v["region"]) } else [] end
          @comment = json["comment"]
          @records = json["records"].map { |j| RecordConfig.new(j, @domain, json["zone-id"]) }
          @ignored = if json["ignored"].nil? then [] else json["ignored"] end
        end
      end

      # Public: Populate this ZoneConfig from an AWS resource
      #
      # aws - the aws resource
      def populate(aws)
        @id = aws.id.sub(/\/hostedzone\//, '')
        @domain = aws.name
        @private = aws.config.private_zone
        @vpc = if @private then aws.vpc else nil end
        @comment = aws.config.comment
        @records = aws.records.map do |record|
          r = RecordConfig.new()
          r.populate(record, @domain)
          r
        end
      end

      # Public: Get the config as a prettified JSON string.
      #
      # Returns the JSON string
      def pretty_json
        JSON.pretty_generate({
          "zone-id" => @id,
          "domain" => @domain,
          "private" => @private,
          "vpc" => if @vpc.nil? then nil else @vpc.map(&:to_hash) end,
          "comment" => @comment,
          "records" => @records.map(&:to_hash),
          "ignored" => if @ignored.nil? then [] else @ignored end,
        }.reject { |k, v| v.nil? })
      end

      # Public: Produce an array of differences between this local configuration and the
      # configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the ZoneDiffs that were found
      def diff(aws)
        diffs = []

        if @comment != aws.config.comment
          diffs << ZoneDiff.new(ZoneChange::COMMENT, aws, self)
        end
        if @domain != aws.name
          diffs << ZoneDiff.new(ZoneChange::DOMAIN, aws, self)
        end
        if @private != aws.config.private_zone
          diffs << ZoneDiff.new(ZoneChange::PRIVATE, aws, self)
        end
        if @private and @vpc.sort != aws.vpc.sort
          diffs << ZoneDiff.new(ZoneChange::VPC, aws, self)
        end

        record_diffs = diff_records(aws.records)
        if !record_diffs.empty?
          diffs << ZoneDiff.records(record_diffs, self)
        end

        diffs
      end

      private

      # The unique key on a record is a combination of name and type
      RecordKey = Struct.new(:name, :type)

      # Internal: Produce an array of differences between local record configuration and the
      # configuration in AWS.
      #
      # aws - an array of records in aws
      #
      # Returns an array of the RecordDiffs that were found
      def diff_records(aws)
        diffs = []

        # map the records to their keys
        aws = Hash[aws.map { |r| [RecordKey.new(r.name, r.type), r] }]
        local = Hash[@records.map { |r| [RecordKey.new(r.name, r.type), r] }]

        # find records in aws that are not configured locally, ignoring the NS and SOA
        # record for the domain
        aws.each do |key, record|
          if !local.include?(key)
            if @domain == record.name and record.type == "NS"
              diffs << RecordDiff.ignored("Default NS record is supplied in AWS, but not locally. It will be ignored when syncing.", record)
            elsif @domain == record.name and record.type == "SOA"
              diffs << RecordDiff.ignored("Default SOA record is supplied in AWS, but not locally. It will be ignored when syncing.", record)
            elsif !@ignored.find_index { |i| !record.name.match(i).nil? }.nil?
              diffs << RecordDiff.ignored("Record (#{record.type}) #{record.name} is ignored by your blacklist", aws)
            else
              diffs << RecordDiff.unmanaged(record)
            end
          end
        end

        local.each do |key, record|
          if !aws.include?(key)
            diffs << RecordDiff.added(record)
          else
            d = record.diff(aws[key])
            if !d.empty?
              diffs << RecordDiff.changed(d, record)
            end
          end
        end

        diffs.flatten
      end
    end
  end
end
