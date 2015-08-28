require "s3/models/ReplicationDiff"
require "iam/IAM"

module Cumulus
  module S3
    class ReplicationConfig
      attr_reader :destination
      attr_reader :iam_role
      attr_reader :prefixes

      # Public: Constructor
      #
      # json - a hash representing the JSON configuration. Expects to be passed
      # the "replication" node of S3 bucket configuration.
      def initialize(json = nil)
        if json
          @destination = json["destination"]
          @iam_role = json["iam-role"]
          @prefixes = json["prefixes"] || []
        end
      end

      # Public: Produce an AWS hash representing this ReplicationConfig
      #
      # Returns the hash
      def to_aws
        {
          role: IAM.get_role_arn(@iam_role),
          rules: if @prefixes.empty?
            [{
              prefix: "",
              status: "Enabled",
              destination: {
                bucket: "arn:aws:s3:::#{@destination}"
              }
            }]
          else
            @prefixes.map do |prefix|
              {
                prefix: prefix,
                status: "Enabled",
                destination: {
                  bucket: "arn:aws:s3:::#{@destination}"
                }
              }
            end
          end
        }
      end

      # Public: Converts this ReplicationConfig to a hash that matches Cumulus
      # configuration.
      #
      # Returns the hash
      def to_h
        {
          "iam-role" => @iam_role,
          "prefixes" => if !@prefixes.empty? then @prefixes end,
          "destination" => @destination,
        }.reject { |k, v| v.nil? }
      end

      # Public: Produce an array of differences between this local configuration
      # and the configuration in AWS
      #
      # aws - the AWS resource
      #
      # Returns an array of the ReplicationDiff that were found
      def diff(aws)
        diffs = []

        if @destination != aws.destination
          diffs << ReplicationDiff.new(ReplicationChange::DESTINATION, aws, self)
        end
        if @iam_role != aws.iam_role
          diffs << ReplicationDiff.new(ReplicationChange::ROLE, aws, self)
        end
        if @prefixes.sort != aws.prefixes
          diffs << ReplicationDiff.new(ReplicationChange::PREFIX, aws, self)
        end

        diffs
      end

      # Public: Populate this ReplicationConfig with the values in an AWS
      # replication configuration.
      #
      # aws - the aws object to populate from
      def populate!(aws)
        @destination = aws.rules[0].destination.bucket
        @destination = @destination[(@destination.rindex(":") + 1)..-1]
        @iam_role = aws.role[(aws.role.rindex("/") + 1)..-1]
        @prefixes = aws.rules.map(&:prefix)

        if @prefixes.size == 1 and @prefixes[0] == ""
          @prefixes = []
        end
      end

      # Public: Check ReplicationConfig equality with other objects.
      #
      # other - the other object to check
      #
      # Returns whether this ReplicationConfig is equal to `other`
      def ==(other)
        if !other.is_a? ReplicationConfig or
            @destination != other.destination or
            @iam_role != other.iam_role or
            @prefixes.sort != other.prefix.sort
          false
        else
          true
        end
      end

      # Public: Check if this ReplicationConfig is not equal to the other object
      #
      # other - the other object to check
      #
      # Returns whether this ReplicationConfig is not equal to `other`
      def !=(other)
        !(self == other)
      end
    end
  end
end
