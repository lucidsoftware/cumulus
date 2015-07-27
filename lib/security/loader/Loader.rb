require "common/BaseLoader"
require "conf/Configuration"
require "security/models/SecurityGroupConfig"

# Public: Load Security Group assets
module Loader
  include BaseLoader

  @@groups_dir = Configuration.instance.security.groups_directory
  @@subnets_file = Configuration.instance.security.subnets_file

  # Public: Load all the security group configurations as SecurityGroupConfig objects
  #
  # Returns an array of SecurityGroupConfig
  def Loader.groups
    BaseLoader.resources(@@groups_dir, &SecurityGroupConfig.method(:new))
  end

  # Public: Get the local definition of a subnet group.
  #
  # name - the name of the subnet group to get
  #
  # Returns an array of ip addresses that is empty if there is no subnet group with that name
  def Loader.subnet_group(name)
    if self.subnet_groups[name].nil?
      []
    else
      self.subnet_groups[name]
    end
  end

  private

  # Internal: Get the subnet group definitions
  #
  # Returns a hash that maps group name to an array of ips
  def Loader.subnet_groups
    @subnet_groups ||= self.load_subnet_groups
  end

  # Internal: Load the subnet group definitions
  #
  # Returns a hash that maps group name to an array of ips
  def Loader.load_subnet_groups
    BaseLoader.resource(@@subnets_file, "", &Proc.new { |name, json| json })
  end
end
