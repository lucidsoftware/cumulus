require "conf/Configuration"
require "iam/models/GroupConfig"
require "iam/models/StatementConfig"
require "iam/models/RoleConfig"
require "iam/models/UserConfig"

require "json"

# Public: A module that handles loading all the json configuration files and
# creating objects from them.
module Loader

  # Public: Load all the roles defined in configuration.
  #
  # Returns an Array of RoleConfig objects defined by the roles configuration
  # files.
  def Loader.roles
    roles_dir = Configuration.instance.iam.roles_directory
    Loader.resources(roles_dir, &Proc.new { |f| Loader.role(f) })
  end

  # Public: Load a role defined in configuration
  #
  # file - the name of the role to load
  #
  # Returns a RoleConfig object defined by the role configuration files.
  def Loader.role(file)
    roles_dir = Configuration.instance.iam.roles_directory
    RoleConfig.new(JSON.parse(File.read(File.join(roles_dir, file))))
  end

  # Public: Load all the users defined in configuration.
  #
  # Returns an Array of UserConfig objects defined in user configuration files.
  def Loader.users
    users_dir = Configuration.instance.iam.users_directory
    Loader.resources(users_dir, &Proc.new { |f| Loader.user(f) })
  end

  # Public: Load a user defined in configuration
  #
  # file - the file the user definition is found in
  #
  # Returns the UserConfig object defined by the file.
  def Loader.user(file)
    users_dir = Configuration.instance.iam.users_directory
    UserConfig.new(JSON.parse(File.read(File.join(users_dir, file))))
  end

  # Public: Load all the groups defined in configuration.
  #
  # Returns an Array of GroupConfig objects defined by the groups configuration
  # files.
  def Loader.groups
    groups_dir = Configuration.instance.iam.groups_directory
    Loader.resources(groups_dir, &Proc.new { |f| Loader.group(f) })
  end

  # Public: Load a group defined in configuration
  #
  # file - the file the group definition is found in
  #
  # Returns the GroupConfig object defined by the file
  def Loader.group(file)
    groups_dir = Configuration.instance.iam.groups_directory
    GroupConfig.new(JSON.parse(File.read(File.join(groups_dir, file))))
  end

  # Internal: Load the resources in a directory, handling each file with the
  # function passed in.
  #
  # dir               - the directory to load resources from
  # individual_loader - the function that loads a resource from each file name
  #
  # Returns an array of resources
  def Loader.resources(dir, &individual_loader)
    Dir.entries(dir)
    .reject { |f| f == "." or f == ".." or File.directory?(File.join(dir, f)) }
    .map { |f| individual_loader.call(f) }
  end

  # Public: Load in a static policy as StatementConfig object
  #
  # file - the String name of the static policy file to load
  #
  # Returns a StatementConfig object corresponding to the static policy
  def Loader.static_policy(file)
    static_policy_dir = Configuration.instance.iam.static_policy_directory
    json = JSON.parse(File.read(File.join(static_policy_dir, file)))

    if json.is_a?(Array)
      json.map do |s|
        StatementConfig.new(s)
      end
    else
      StatementConfig.new(json)
    end
  end

  # Public: Load in a template policy, apply variables, and create a
  # StatementConfig object from the result
  #
  # file      - the String name of the template policy file to load
  # variables - a Hash of variables to apply to the template
  #
  # Returns a StatementConfig object corresponding to the applied template policy
  def Loader.template_policy(file, variables)
    template_dir = Configuration.instance.iam.template_policy_directory
    template = File.read(File.join(template_dir, file))
    variables.each do |key, value|
      template.gsub!("{{#{key}}}", value)
    end
    json = JSON.parse(template)

    if json.is_a?(Array)
      json.map { |s| StatementConfig.new(s) }
    else
      StatementConfig.new(json)
    end
  end

  # Public: Load the JSON string that is a role's policy document from a file.
  #
  # file - the String name of the policy document file to load
  #
  # Returns the String contents of the policy document file
  def Loader.policy_document(file)
    policy_dir = Configuration.instance.iam.policy_document_directory
    File.read(File.join(policy_dir, file))
  end

end
