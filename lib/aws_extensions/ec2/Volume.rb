module AwsExtensions
  module EC2
    module Volume

      # Public: Returns the value of the "Group" tag for the Volume
      def group
        self.tags.select { |tag| tag.key == "Group" }.first.value
      rescue
      	nil
      end

    end
  end
end
