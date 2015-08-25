require "cloudfront/models/CustomOriginDiff"

module Cumulus
  module CloudFront
    CustomOriginConfig = Struct.new(:http_port, :https_port, :protocol_policy) do

      def diff(aws)
        diffs = []

        if aws.nil? or self.http_port != aws.http_port
          diffs << CustomOriginDiff.new(CustomOriginChange::HTTP, aws, self)
        end

        if aws.nil? or self.https_port != aws.https_port
          diffs << CustomOriginDiff.new(CustomOriginChange::HTTPS, aws, self)
        end

        if aws.nil? or self.protocol_policy != aws.origin_protocol_policy
          diffs << CustomOriginDiff.new(CustomOriginChange::POLICY, aws, self)
        end

        diffs
      end

      def to_local
        {
          "http-port" => self.http_port,
          "https-port" => self.https_port,
          "protocol-policy" => self.protocol_policy,
        }.reject { |k, v| v.nil? }
      end
    end
  end
end
