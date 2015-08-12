require "route53/models/RecordDiff"

# Public: An object representing configurationf for a single record in a zone
class RecordConfig
  attr_reader :name
  attr_reader :ttl
  attr_reader :type
  attr_reader :value

  # Public: Constructor.
  #
  # json   - a hash containing the JSON configuration for the record
  # domain - the domain of the zone this record belongs to
  def initialize(json, domain)
    if !json.nil?
      @name = "#{json["name"].chomp(".")}.#{domain}".chomp(".")
      @ttl = json["ttl"]
      @type = json["type"]
      @value = json["value"]

      # TXT and SPF records have each value wrapped in quotes
      if @type == "TXT" or @type == "SPF"
        @value = @value.map { |v| "\"#{v}\"" }
      end
    end
  end

  # Public: Produce an array of differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the AWS resource
  #
  # Returns an array of the RecordDiffs that were found
  def diff(aws)
    diffs = []

    if @ttl != aws.ttl
      diffs << SingleRecordDiff.new(RecordChange::TTL, aws, self)
    end
    if @value.sort != aws.resource_records.map(&:value).sort
      diffs << SingleRecordDiff.new(RecordChange::VALUE, aws, self)
    end

    diffs
  end

  # Public: Produce a `resource_records` array that is analogous to the one used in AWS from
  # the values array used by Cumulus
  #
  # Returns the `resource_records`
  def resource_records
    @value.map { |v| { value: v } }
  end

  # Public: Produce a useful human readable version of the name of this RecordConfig
  #
  # Returns the string name
  def readable_name
    "(#{@type}) #{@name}"
  end
end
