require "json"

module Cumulus
  # Public: A module that contains helper methods for the configuration classes.
  #
  # When mixing in this module, make sure your class has a @node instance variable
  # for what node in the json it expect to get config from, ie. "s3" or "iam"
  module Config
    @@json = nil
    @@project_root = nil

    class << self
      def json
        @@json
      end

      def json=(value)
        @@json = value
      end

      def project_root
        @@project_root
      end

      def project_root=(value)
        @@project_root = value
      end
    end

    private

    # Internal: Take a path relative to the project root and turn it into an
    # absolute path
    #
    # relative_path - The String path from `project_root` to the desired file
    #
    # Returns the absolute path as a String
    def absolute_path(relative_path)
      if relative_path.start_with?("/")
        relative_path
      else
        File.join(@@project_root, relative_path)
      end
    end

    # Internal: Handle any KeyErrors that occur while getting a configuration value
    # by printing out a message describing the missing key and exiting.
    #
    # key     - the full key to get ex. `s3.buckets.directory`
    # handler - a block that will do additional processing on the key. If nil,
    #           the value is returned as is.
    #
    # Returns the configuration value if successful
    def conf(key, &handler)
      value = nil
      key.split(".").each do |part|
        if value
          value = value.fetch(part)
        else
          value = @@json.fetch(part)
        end
      end

      if handler
        handler.call(value)
      else
        value
      end
    rescue KeyError
      puts "Your configuration file is missing $.#{key}."
      exit
    end

    # Internal: A version of `conf` that will apply the `absolute_path` method to
    # the configuration value.
    #
    # key - the full key to get. ex. `s3.buckets.directory`
    #
    # Returns the configuration value as an absolute path
    def conf_abs_path(key)
      conf(key) { |value| absolute_path(value) }
    end
  end

  # Public: Contains the configuration values set in the configuration.json file.
  # Provides a Singleton that can be accessed throughout the application.
  class Configuration
    include Config

    attr_reader :colors_enabled
    attr_reader :iam, :autoscaling, :route53, :s3, :security, :cloudfront, :elb
    attr_reader :region, :profile

    # Internal: Constructor. Sets up the `instance` variable, which is the access
    # point for the Singleton.
    #
    # project_root  - The String path to the directory the project is running in
    # file_path     - The String path from `project_root` to the configuration
    #                 file
    # profile       - The String profile name that will be used to make AWS API calls
    def initialize(project_root, file_path, profile)
      Config.project_root = project_root;
      Config.json = JSON.parse(File.read(absolute_path(file_path)))
      @profile = profile
      @colors_enabled = conf "colors-enabled"
      @region = conf "region"
      @iam = IamConfig.new
      @autoscaling = AutoScalingConfig.new
      @route53 = Route53Config.new
      @security = SecurityConfig.new
      @cloudfront = CloudFrontConfig.new
      @s3 = S3Config.new
      @elb = ELBConfig.new
    end

    class << self
      # Public: Initialize the Configuration Singleton. Must be called before any
      # access to `Configuration.instance` is used.
      #
      # project_root  - The String path to the directory the project is running in
      # file_path     - The String path from `project_root` to the configuration
      #                 file
      def init(project_root, file_path, profile)
        instance = new(project_root, file_path, profile)
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
      include Config

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
      def initialize
        @groups_directory = conf_abs_path "iam.groups.directory"
        @policy_document_directory = conf_abs_path "iam.roles.policy-document-directory"
        @policy_prefix = conf "iam.policies.prefix"
        @policy_suffix = conf "iam.policies.suffix"
        @policy_version = conf "iam.policies.version"
        @roles_directory = conf_abs_path "iam.roles.directory"
        @static_policy_directory = conf_abs_path "iam.policies.static.directory"
        @template_policy_directory = conf_abs_path "iam.policies.templates.directory"
        @users_directory = conf_abs_path "iam.users.directory"
      end
    end

    # Public: Inner class that contains AutoScaling configuration options
    class AutoScalingConfig
      include Config

      attr_reader :groups_directory
      attr_reader :override_launch_config_on_sync
      attr_reader :static_policy_directory
      attr_reader :template_policy_directory

      # Public: Constructor.
      def initialize
        @groups_directory = conf_abs_path "autoscaling.groups.directory"
        @override_launch_config_on_sync = conf "autoscaling.groups.override-launch-config-on-sync"
        @static_policy_directory = conf_abs_path "autoscaling.policies.static.directory"
        @template_policy_directory = conf_abs_path "autoscaling.policies.templates.directory"
      end

    end

    # Public: Inner class that contains Route53 configuration options
    class Route53Config
      include Config

      attr_reader :includes_directory
      attr_reader :print_all_ignored
      attr_reader :zones_directory

      # Public: Constructor
      def initialize
        @includes_directory = conf_abs_path "route53.includes.directory"
        @print_all_ignored = conf "route53.print-all-ignored"
        @zones_directory = conf_abs_path "route53.zones.directory"
      end
    end

    # Public: Inner class that contains S3 configuration options
    class S3Config
      include Config

      attr_reader :buckets_directory
      attr_reader :cors_directory
      attr_reader :policies_directory
      attr_reader :print_progress

      # Public: Constructor
      def initialize
        @node = "s3"
        @buckets_directory = conf_abs_path "s3.buckets.directory"
        @cors_directory = conf_abs_path "s3.buckets.cors.directory"
        @policies_directory = conf_abs_path "s3.buckets.policies.directory"
        @print_progress = conf "s3.print-progress"
      end
    end

    # Public: Inner class that contains Security Group configuration options
    class SecurityConfig
      include Config

      attr_reader :groups_directory
      attr_reader :outbound_default_all_allowed
      attr_reader :subnets_file

      # Public: Constructor.
      def initialize
        @groups_directory = conf_abs_path "security.groups.directory"
        @outbound_default_all_allowed = conf "security.outbound-default-all-allowed"
        @subnets_file = conf_abs_path "security.subnets-file"
      end

    end

    # Public: Inner class that contains cloudfront configuration options
    class CloudFrontConfig
      include Config

      attr_reader :distributions_directory
      attr_reader :invalidations_directory

      def initialize
        @distributions_directory = conf_abs_path "cloudfront.distributions.directory"
        @invalidations_directory = conf_abs_path "cloudfront.invalidations.directory"
      end
    end

    # Public: Inner class that contains elb configuration options
    class ELBConfig
      include Config

      attr_reader :load_balancers_directory
      attr_reader :listeners_directory
      attr_reader :policies_directory

      def initialize
        @load_balancers_directory = conf_abs_path "elb.load-balancers.directory"
        @listeners_directory = conf_abs_path "elb.listeners.directory"
        @policies_directory = conf_abs_path "elb.policies.directory"
      end
    end

  end
end
