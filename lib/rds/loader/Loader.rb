require "rds/models/InstanceConfig"
require "common/BaseLoader"
require "conf/Configuration"

module Cumulus
  module RDS
    # public load RDS assets
    module Loader
      include Common::BaseLoader

      @@instance_dir = Configuration.instance.rds.instances_directory
      @@instance_loader = Proc.new { |name, json| InstanceConfig.new(name, json) }

      def self.instances
        Common::BaseLoader.resources(@@instance_dir, &@@instance_loader)
      end

    end
  end
end
