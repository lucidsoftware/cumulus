module AwsExtensions
  module EC2
    module Subnet

      # Public: Returns the value of the "Name" tag for the subnet or nil if there is not one
      def name
        self.tags.select { |tag| tag.key == "Name" }.first.value
      rescue
        nil
      end

      # Implement comparison by using subnet id
      def <=>(other)
        self.subnet_id <=> other.subnet_id
      end

    end
  end
end
