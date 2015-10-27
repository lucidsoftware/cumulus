module AwsExtensions
  module EC2
    module Instance

      # Public: Returns the value of the "Name" tag for the Instance
      def name
        self.tags.select { |tag| tag.key == "Name" }.first.value
      rescue
      	nil
      end

    end
  end
end
