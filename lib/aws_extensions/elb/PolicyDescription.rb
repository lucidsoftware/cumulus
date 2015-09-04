module AwsExtensions
  module ELB
    module PolicyDescription
      # Public: Convert this Aws::ELB::Types::PolicyDescription
      # into a json version for migrating to Cumulus
      def to_cumulus_hash
        {
          "type" => self.policy_type_name,
          "attributes" => (self.policy_attribute_descriptions.map do |attribute|
            [attribute.attribute_name, attribute.attribute_value]
          end).to_h
        }
      end
    end
  end
end
