require "cloudfront/models/CustomOriginDiff"

module Cumulus
  module CloudFront
    CustomOriginConfig = Struct.new(:http_port, :https_port, :protocol_policy) do

      def diff(aws)
        diffs = []

        aws_http_port = aws && aws.http_port
        if self.http_port != aws_http_port
          diffs << CustomOriginDiff.new(CustomOriginChange::HTTP, aws_http_port, self.http_port)
        end

        aws_https_port = aws && aws.https_port
        if self.https_port != aws_https_port
          diffs << CustomOriginDiff.new(CustomOriginChange::HTTPS, aws_https_port, self.https_port)
        end

        aws_protocol = aws && aws.origin_protocol_policy
        if self.protocol_policy != aws_protocol
          diffs << CustomOriginDiff.new(CustomOriginChange::POLICY, aws_protocol, self.protocol_policy)
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
