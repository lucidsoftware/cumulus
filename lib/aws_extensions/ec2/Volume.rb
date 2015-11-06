module AwsExtensions
  module EC2
    module Volume

      # Public: Returns the value of the "Group" tag for the Volume
      def group
        self.tags.select { |tag| tag.key == "Group" }.first.value
      rescue
      	nil
      end

      # Public: Returns true if the volume is attached or attaching to anything
      def attached?
        self.attachments.map(&:state).any? { |state| state == "attached" || state == "attaching" }
      end

      # Public: Returns true if the volume is not attached or attaching to anything
      def detached?
        !self.attached?
      end

    end
  end
end
