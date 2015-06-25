require "autoscaling/models/GroupConfig"
require "common/BaseLoader"
require "conf/Configuration"

# Public: Load AutoScaling assets
module Loader
  include BaseLoader

  @@groups_dir = Configuration.instance.autoscaling.groups_directory
  @@group_loader = Proc.new { |json| GroupConfig.new(json) }

  # Public: Load all autoscaling group configurations as GroupConfig objects
  #
  # Returns an array of GroupConfig objects
  def Loader.groups
    BaseLoader.resources(@@groups_dir, &@@group_loader)
  end

end
