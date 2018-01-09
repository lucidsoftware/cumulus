require "cloudfront/models/CustomOriginDiff"

module Cumulus
  module CloudFront
    CustomOriginConfig = Struct.new(:http_port, :https_port, :protocol_policy, :origin_ssl_protocols, 
                                    :origin_read_timeout, :origin_keepalive_timeout) do

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

        aws_read_timeout = aws && aws.origin_read_timeout
        if self.origin_read_timeout != aws_read_timeout
          diffs << CustomOriginDiff.new(CustomOriginChange::READ_TIMEOUT, aws_read_timeout, self.origin_read_timeout)
        end

        aws_keepalive_timeout = aws && aws.origin_keepalive_timeout
        if self.origin_keepalive_timeout != aws_keepalive_timeout
          diffs << CustomOriginDiff.new(CustomOriginChange::KEEPALIVE_TIMEOUT, aws_keepalive_timeout, self.origin_keepalive_timeout)
        end

        if self.origin_ssl_protocols
          ssl_protocol_diffs = self.origin_ssl_protocols.diff(aws && aws.origin_ssl_protocols)
        else
          if aws.origin_ssl_protocols && aws.origin_protocol_policy != "http-only"
            ssl_protocol_diffs = OriginSslProtocols.new([]).diff(aws.origin_ssl_protocols)
          end
        end
        if ssl_protocol_diffs && ssl_protocol_diffs.length > 0
          diffs << CustomOriginDiff.ssl_protocols(ssl_protocol_diffs, aws, self)
        end

        diffs
      end

      def to_local
        {
          "http-port" => self.http_port,
          "https-port" => self.https_port,
          "protocol-policy" => self.protocol_policy,
          "origin_read_timeout" => self.origin_read_timeout,
          "origin_keepalive_timeout" => self.origin_keepalive_timeout,
          "origin-ssl-protocols" => if self.origin_ssl_protocols
            self.origin_ssl_protocols.to_local
          end
        }.reject { |k, v| v.nil? }
      end
    end
  end
end
