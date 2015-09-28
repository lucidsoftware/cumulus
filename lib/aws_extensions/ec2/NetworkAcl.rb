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

      # Public: Returns the enteries that are diffable by leaving out
      # the last rule that denies all
      def diffable_entries
        self.entries.select { |entry| entry.rule_number < 32767 }
      end

    end
  end
end
