module AwsExtensions
  module EC2
    module NetworkInterface

      # Public: Returns the value of the "Name" tag for the route table
      def name
        self.tag_set.select { |tag| tag.key == "Name" }.first.value
      rescue
      	nil
      end

    end
  end
end
