require "common/BaseLoader"
require "conf/Configuration"
require "security/models/SecurityGroupConfig"

# Public: Load Security Group assets
module Loader
  include BaseLoader

  @@groups_dir = Configuration.instance.security.groups_directory
  @@group_loader = Proc.new { |name, json| SecurityGroupConfig.new(name, json) }

  # Public: Load all the security group configurations as SecurityGroupConfig bojects
  #
  # Returns an array of SecurityGroupConfig
  def Loader.groups
    BaseLoader.resources(@@groups_dir, &@@group_loader)
  end

end
