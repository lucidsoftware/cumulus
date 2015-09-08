module AwsExtensions
  module ELB
    module PolicyDescription
      # Public: Convert this Aws::ELB::Types::PolicyDescription
      # into a json version for migrating to Cumulus
      def to_cumulus_hash
        {
          "type" => self.policy_type_name,
          "attributes" => Hash[self.policy_attribute_descriptions.map { |a| [a.attribute_name, a.attribute_value] }]
        }
      end
    end
  end
end
