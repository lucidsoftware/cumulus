require "common/BaseLoader"
require "conf/Configuration"
require "route53/models/ZoneConfig"

# Public: Load Route53 assets
module Loader
  include BaseLoader

  @@zones_dir = Configuration.instance.route53.zones_directory

  # Public: Load all the zone configurations as ZoneConfig objects
  #
  # Returns an array of ZoneConfig
  def self.zones
    BaseLoader.resources(@@zones_dir, &ZoneConfig.method(:new))
  end

end
