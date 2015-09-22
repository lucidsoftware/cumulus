module AwsExtensions
  module EC2
    module DhcpOptions

      # Public: Returns the value of the domain-name-servers
      def domain_name_servers
        get_attribute_value("domain-name-servers") || []
      end

      # Public: Returns the value of domain-name
      def domain_name
        get_attribute_value("domain-name")
      end

      # Public: Returns the value of ntp-servers if set
      def ntp_servers
        get_attribute_value("ntp-servers") || []
      end

      # Public: Returns the value of netbios-attribute-servers
      def netbios_name_servers
        get_attribute_value("netbios-attribute-servers") || []
      end

      # Public: Returns the value of netbios-node-type
      def netbios_node_type
        get_attribute_value("netbios-node-type")
      end

      private

      # Internal: Gets an named attribute from the dhcp_configuration
      def get_attribute_value(attr_name)
        self.dhcp_configurations.select { |conf| conf.key == attr_name }.first.values.map(&:value)
      rescue
        nil
      end

    end
  end
end
