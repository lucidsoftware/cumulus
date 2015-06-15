require "json"

# Public: Contains the configuration values set in the configuration.json file.
# Provides a Singleton that can be accessed throughout the application.
class Configuration

  attr_reader :colors_enabled
  attr_reader :iam
  attr_reader :region

  # Internal: Constructor. Sets up the `instance` variable, which is the access
  # point for the Singleton.
  #
  # project_root  - The String path to the directory the project is running in
  # file_path     - The String path from `project_root` to the configuration
  #                 file
  def initialize(project_root, file_path)
    @project_root = project_root;
    json = JSON.parse(File.read(absolute_path(file_path)))
    @colors_enabled = json["colors-enabled"]
    @region = json["region"]
    @iam = IamConfig.new(json["iam"], self)
  end

  # Public: Take a path relative to the project root and turn it into an
  # absolute path
  #
  # relative_path - The String path from `project_root` to the desired file
  #
  # Returns the absolute path as a String
  def absolute_path(relative_path)
    if relative_path.start_with?("/")
      relative_path
    else
      File.join(@project_root, relative_path)
    end
  end

  class << self
    # Public: Initialize the Configuration Singleton. Must be called before any
    # access to `Configuration.instance` is used.
    #
    # project_root  - The String path to the directory the project is running in
    # file_path     - The String path from `project_root` to the configuration
    #                 file
    def init(project_root, file_path)
      instance = new(project_root, file_path)
      @@instance = instance
    end

    # Public: The Singleton instance of Configuration.
    #
    # Returns the Configuration instance.
    def instance
      @@instance
    end

    private :new
  end

  # Public: Inner class that contains IAM configuration options
  class IamConfig

    attr_reader :policy_prefix
    attr_reader :policy_suffix
    attr_reader :policy_version
    attr_reader :static_policy_directory
    attr_reader :template_policy_directory
    attr_reader :roles_directory
    attr_reader :policy_document_directory
    attr_reader :users_directory

    # Public: Constructor.
    #
    # json   - a hash that contains IAM configuration values. IamConfig expects
    #          to be passed values from the "iam" node of configuration.json
    # parent - reference to the parent Configuration that spawned this IamConfig
    def initialize(json, parent)
      @policy_prefix = json["policies"]["prefix"]
      @policy_suffix = json["policies"]["suffix"]
      @policy_version = json["policies"]["version"]
      @static_policy_directory = parent.absolute_path(json["policies"]["static"]["directory"])
      @template_policy_directory = parent.absolute_path(json["policies"]["templates"]["directory"])
      @roles_directory = parent.absolute_path(json["roles"]["directory"])
      @policy_document_directory = parent.absolute_path(json["roles"]["policy-document-directory"])
      @users_directory = parent.absolute_path(json["users"]["directory"])
    end
  end

end
