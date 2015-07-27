require "json"

# Public: Contains the configuration values set in the configuration.json file.
# Provides a Singleton that can be accessed throughout the application.
class Configuration

  attr_reader :colors_enabled
  attr_reader :iam, :autoscaling, :security
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
    @autoscaling = AutoScalingConfig.new(json["autoscaling"], self)
    @security = SecurityConfig.new(json["security"], self)
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

    attr_reader :groups_directory
    attr_reader :policy_document_directory
    attr_reader :policy_prefix
    attr_reader :policy_suffix
    attr_reader :policy_version
    attr_reader :roles_directory
    attr_reader :static_policy_directory
    attr_reader :template_policy_directory
    attr_reader :users_directory

    # Public: Constructor.
    #
    # json   - a hash that contains IAM configuration values. IamConfig expects
    #          to be passed values from the "iam" node of configuration.json
    # parent - reference to the parent Configuration that spawned this IamConfig
    def initialize(json, parent)
      @groups_directory = parent.absolute_path(json["groups"]["directory"])
      @policy_document_directory = parent.absolute_path(json["roles"]["policy-document-directory"])
      @policy_prefix = json["policies"]["prefix"]
      @policy_suffix = json["policies"]["suffix"]
      @policy_version = json["policies"]["version"]
      @roles_directory = parent.absolute_path(json["roles"]["directory"])
      @static_policy_directory = parent.absolute_path(json["policies"]["static"]["directory"])
      @template_policy_directory = parent.absolute_path(json["policies"]["templates"]["directory"])
      @users_directory = parent.absolute_path(json["users"]["directory"])
    end
  end

  # Public: Inner class that contains AutoScaling configuration options
  class AutoScalingConfig

    attr_reader :groups_directory
    attr_reader :override_launch_config_on_sync
    attr_reader :static_policy_directory
    attr_reader :template_policy_directory

    # Public: Constructor.
    #
    # json   - a hash that contains AutoScaling configuration values.
    #          AutoScalingConfig expects to be passed values from the
    #          "autoscaling" node of configuration.json
    # parent - reference to the parent Configuration that spawned this
    #          AutoScalingConfig
    def initialize(json, parent)
      @groups_directory = parent.absolute_path(json["groups"]["directory"])
      @override_launch_config_on_sync = json["groups"]["override-launch-config-on-sync"]
      @static_policy_directory = parent.absolute_path(json["policies"]["static"]["directory"])
      @template_policy_directory = parent.absolute_path(json["policies"]["templates"]["directory"])
    end

  end

  # Public: Inner class that contains Security Group configuration options
  class SecurityConfig

    attr_reader :groups_directory
    attr_reader :outbound_default_all_allowed
    attr_reader :subnets_file

    # Public: Constructor.
    #
    # json   - a hash that contains Security Group configuration values. SecurityConfig
    #          expects to be passed values from the "security" node of configuration.json
    # parent - reference to the parent Configuration that spawned this SecurityConfig
    def initialize(json, parent)
      @groups_directory = parent.absolute_path(json["groups"]["directory"])
      @outbound_default_all_allowed = json["outbound-default-all-allowed"]
      @subnets_file = parent.absolute_path(json["subnets-file"])
    end

  end

end
