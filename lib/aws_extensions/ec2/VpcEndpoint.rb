module AwsExtensions
  module EC2
    module VpcEndpoint

      def parsed_policy
        JSON.parse(URI.decode(self.policy_document))
      end

    end
  end
end
