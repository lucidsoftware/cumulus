require "common/BaseLoader"
require "conf/Configuration"
require "route53/models/ZoneConfig"

# Public: Load Route53 assets
module Cumulus
  module Route53
    module Loader
      include Common::BaseLoader

      @@zones_dir = Configuration.instance.route53.zones_directory
      @@includes_dir = Configuration.instance.route53.includes_directory

      # Public: Load all the zone configurations as ZoneConfig objects
      #
      # Returns an array of ZoneConfig
      def self.zones
        Common::BaseLoader::resources(@@zones_dir, &ZoneConfig.method(:new))
      end

      # Public: Load a single "includes file" as parsed JSON
      #
      # name - the name of the file to include
      #
      # Returns an array of parsed JSON
      def self.includes_file(name)
        Common::BaseLoader::resource(name, @@includes_dir, &Proc.new { |n, json| json })
      end

    end
  end
end
