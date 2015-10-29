require "common/BaseLoader"
require "conf/Configuration"
require "ec2/models/InterfaceConfig"

module Cumulus
  module EC2
    module NetworkInterfaceLoader

      include Common::BaseLoader

      @@interfaces_dir = Configuration.instance.ec2.network_interfaces_directory

      def self.interfaces
        Common::BaseLoader::resources(@@interfaces_dir, &InterfaceConfig.method(:new))
      end

    end
  end
end