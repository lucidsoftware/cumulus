module AwsExtensions
  module EC2
    module Instance

      # Public: Returns the value of the "Name" tag for the Instance
      def name
        self.tags.select { |tag| tag.key == "Name" }.first.value
      rescue
      	nil
      end

      # Public: Returns an array of the block device mappings that are not for the root device
      def nonroot_devices
        self.block_device_mappings.reject { |m| m.device_name == self.root_device_name }
      end

      # Public: Returns true if the instance is stopped
      def stopped?
        self.state.name == "stopped"
      end

      # Public: Returns true if the instance is terminated
      def terminated?
        self.state.name == "terminated"
      end

    end
  end
end
