require "conf/Configuration"
require "iam/models/StatementConfig"
require "iam/models/RoleConfig"

require "json"

# Public: A module that handles loading all the json configuration files and
# creating objects from them.
module Loader

  # Public: Load all the roles defined in configuration.
  #
  # Returns an Array of RoleConfig objects defined by the roles configuration
  # files.
  def Loader.roles
    roles_dir = Configuration.instance.roles_directory
    Dir.entries(roles_dir)
      .reject do |f|
        f == "." or f == ".." or File.directory?(File.join(roles_dir, f))
      end.map do |file|
        RoleConfig.new(JSON.parse(File.read(File.join(roles_dir, file))))
      end
  end

  # Public: Load in a static policy as StatementConfig object
  #
  # file - the String name of the static policy file to load
  #
  # Returns a StatementConfig object corresponding to the static policy
  def Loader.static_policy(file)
    static_policy_dir = Configuration.instance.static_policy_directory
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
    template_dir = Configuration.instance.template_policy_directory
    template = File.read(File.join(template_dir, file))
    variables.each do |key, value|
      template.gsub!("{{#{key}}}", value)
    end
    StatementConfig.new(JSON.parse(template))
  end

  # Public: Load the JSON string that is a role's policy document from a file.
  #
  # file - the String name of the policy document file to load
  #
  # Returns the String contents of the policy document file
  def Loader.policy_document(file)
    policy_dir = Configuration.instance.policy_document_directory
    File.read(File.join(policy_dir, file))
  end

end
