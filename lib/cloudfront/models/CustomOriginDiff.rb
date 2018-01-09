require "common/models/Diff"
require "util/Colors"

module Cumulus
  module CloudFront

  	# Public: The types of changes that can be made to zones
    module CustomOriginChange
      include Common::DiffChange

      HTTP = Common::DiffChange::next_change_id
      HTTPS = Common::DiffChange::next_change_id
      POLICY = Common::DiffChange::next_change_id
      SSL_PROTOCOLS = Common::DiffChange::next_change_id
      READ_TIMEOUT = Common::DiffChange::next_change_id
      KEEPALIVE_TIMEOUT = Common::DiffChange::next_change_id
    end

    # Public: Represents a single difference between local configuration and AWS
    # configuration of zones.
    class CustomOriginDiff < Common::Diff
      include CustomOriginChange

      attr_accessor :ssl_protocol_changes

      # Public: Static method that produces a diff representing changes in ssl protocols
      #
      # changes - the OriginSslProtocolsDiffs
      # aws     - the aws configuration for the custom origin
      # local   - the local configuration for the custom origin
      #
      # Returns the diff containing those changes
      def self.ssl_protocols(changes, aws, local)
        diff = CustomOriginDiff.new(SSL_PROTOCOLS, aws, local)
        diff.ssl_protocol_changes = changes
        diff
      end

      def diff_string
        case @type
        when HTTP
          [
            "http port:",
            Colors.aws_changes("\tAWS - #{@aws}"),
            Colors.local_changes("\tLocal - #{@local}"),
          ].join("\n")
        when HTTPS
          [
            "https port:",
            Colors.aws_changes("\tAWS - #{@aws}"),
            Colors.local_changes("\tLocal - #{@local}"),
          ].join("\n")
        when POLICY
          [
            "protocol policy:",
            Colors.aws_changes("\tAWS - #{@aws}"),
            Colors.local_changes("\tLocal - #{@local}"),
          ].join("\n")
        when SSL_PROTOCOLS
          [
            "origin ssl protocols:",
            (@ssl_protocol_changes.flat_map do |c|
              c.to_s.lines.map { |l| "\t#{l.chomp}" }
            end).join("\n"),
          ].join("\n")
        when READ_TIMEOUT
          [
            "origin read timeout:",
            Colors.aws_changes("\tAWS -#{@aws}"),
            Colors.local_changes("\tLocal - #{@local}"),
          ].join("\n")
         when KEEPALIVE_TIMEOUT
          [
            "origin keepalive timeout:",
            Colors.aws_changes("\tAWS -#{@aws}"),
            Colors.local_changes("\tLocal - #{@local}"),
          ].join("\n")
        end
      end

      def aws_name
        @aws.id
      end

    end

  end
end
