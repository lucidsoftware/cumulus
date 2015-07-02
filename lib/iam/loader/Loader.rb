require "conf/Configuration"
require "iam/models/GroupConfig"
require "iam/models/StatementConfig"
require "iam/models/RoleConfig"
require "iam/models/UserConfig"
require "common/BaseLoader"

require "json"

# Public: A module that handles loading all the json configuration files and
# creating objects from them.
module Loader
  include BaseLoader

  @@group_loader = Proc.new { |name, json| GroupConfig.new(name, json) }
  @@groups_dir = Configuration.instance.iam.groups_directory
  @@role_loader = Proc.new { |name, json| RoleConfig.new(name, json) }
  @@roles_dir = Configuration.instance.iam.roles_directory
  @@user_loader = Proc.new { |name, json| UserConfig.new(name, json) }
  @@users_dir = Configuration.instance.iam.users_directory
  @@static_policy_dir = Configuration.instance.iam.static_policy_directory
  @@template_dir = Configuration.instance.iam.template_policy_directory
  @@policy_loader = Proc.new do |name, json|
    if json.is_a?(Array)
      json.map do |s|
        StatementConfig.new(s)
      end
    else
      StatementConfig.new(json)
    end
  end

  # Public: Load all the roles defined in configuration.
  #
  # Returns an Array of RoleConfig objects defined by the roles configuration
  # files.
  def Loader.roles
    BaseLoader.resources(@@roles_dir, &@@role_loader)
  end

  # Public: Load a role defined in configuration
  #
  # file - the name of the role to load
  #
  # Returns a RoleConfig object defined by the role configuration files.
  def Loader.role(file)
    BaseLoader.resource(file, @@roles_dir, &@@role_loader)
  end

  # Public: Load all the users defined in configuration.
  #
  # Returns an Array of UserConfig objects defined in user configuration files.
  def Loader.users
    BaseLoader.resources(@@users_dir, &@@user_loader)
  end

  # Public: Load a user defined in configuration
  #
  # file - the file the user definition is found in
  #
  # Returns the UserConfig object defined by the file.
  def Loader.user(file)
    BaseLoader.resource(file, @@users_dir, &@@user_loader)
  end

  # Public: Load all the groups defined in configuration.
  #
  # Returns an Array of GroupConfig objects defined by the groups configuration
  # files.
  def Loader.groups
    BaseLoader.resources(@@groups_dir, &@@group_loader)
  end

  # Public: Load a group defined in configuration
  #
  # file - the file the group definition is found in
  #
  # Returns the GroupConfig object defined by the file
  def Loader.group(file)
    BaseLoader.resource(file, @@groups_dir, &@@group_loader)
  end

  # Public: Load in a static policy as StatementConfig object
  #
  # file - the String name of the static policy file to load
  #
  # Returns a StatementConfig object corresponding to the static policy
  def Loader.static_policy(file)
    BaseLoader.resource(file, @@static_policy_dir, &@@policy_loader)
  end

  # Public: Load in a template policy, apply variables, and create a
  # StatementConfig object from the result
  #
  # file      - the String name of the template policy file to load
  # variables - a Hash of variables to apply to the template
  #
  # Returns a StatementConfig object corresponding to the applied template policy
  def Loader.template_policy(file, variables)
    BaseLoader.template(file, @@template_dir, variables, &@@policy_loader)
  end

  # Public: Load the JSON string that is a role's policy document from a file.
  #
  # file - the String name of the policy document file to load
  #
  # Returns the String contents of the policy document file
  def Loader.policy_document(file)
    policy_dir = Configuration.instance.iam.policy_document_directory
    BaseLoader.load_file(file, policy_dir)
  end

end
