module AwsExtensions
  module EC2
    module NetworkAcl

      # Public: Returns the value of the "Name" tag for the ACL
      def name
        self.tags.select { |tag| tag.key == "Name" }.first.value
      rescue
      	nil
      end

      # Public: Returns the subnet ids associated with an ACL
      def subnet_ids
        self.associations.map { |assoc| assoc.subnet_id }
      end

    end
  end
end
