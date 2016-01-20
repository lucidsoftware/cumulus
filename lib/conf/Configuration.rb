require "json"
require "aws-sdk"

module Cumulus
  # Public: A module that contains helper methods for the configuration classes.
  #
  # When mixing in this module, make sure your class has a @node instance variable
  # for what node in the json it expect to get config from, ie. "s3" or "iam"
  module Config
    @@json = nil
    @@conf_dir = nil

    class << self
      def json
        @@json
      end

      def json=(value)
        @@json = value
      end

      def conf_dir
        @@conf_dir
      end

      def conf_dir=(value)
        @@conf_dir = value
      end
    end

    private

    # Internal: Take a path relative to the project root and turn it into an
    # absolute path
    #
    # relative_path - The String path from `conf_dir` to the desired file
    #
    # Returns the absolute path as a String
    def absolute_path(relative_path)
      if relative_path.start_with?("/")
        relative_path
      else
        File.join(@@conf_dir, relative_path)
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

  end

  # Public: Contains the configuration values set in the configuration.json file.
  # Provides a Singleton that can be accessed throughout the application.
  class Configuration
    include Config

    attr_reader :colors_enabled
    attr_reader :iam, :autoscaling, :route53, :s3, :security, :cloudfront, :elb, :vpc, :kinesis, :sqs, :ec2
    attr_reader :client

    # Internal: Constructor. Sets up the `instance` variable, which is the access
    # point for the Singleton.
    #
    # conf_dir  - The String path to the directory the configuration can be found in
    # profile       - The String profile name that will be used to make AWS API calls
    # assume_role - The ARN of the role to assume when making AWS API calls
    # autoscaling_force_size
    #               -  Determines whether autoscaling should use configured values for
    #                  min/max/desired group size
    def initialize(conf_dir, profile, assume_role, autoscaling_force_size)
      Config.conf_dir = conf_dir;
      Config.json = JSON.parse(File.read(absolute_path("configuration.json")))
      @colors_enabled = conf "colors-enabled"
      @iam = IamConfig.new
      @autoscaling = AutoScalingConfig.new(autoscaling_force_size)
      @route53 = Route53Config.new
      @security = SecurityConfig.new
      @cloudfront = CloudFrontConfig.new
      @s3 = S3Config.new
      @elb = ELBConfig.new
      @vpc = VpcConfig.new
      @kinesis = KinesisConfig.new
      @sqs = SQSConfig.new
      @ec2 = EC2Config.new

      region = conf "region"
      credentials = if assume_role
        Aws::AssumeRoleCredentials.new(
          client: Aws::STS::Client.new(profile: profile, region: region),
          role_arn: assume_role,
          role_session_name: "#{region}-#{@profile}"
        )
      end

      @client = {
        :region => region,
        :profile => profile,
        :credentials => credentials,
      }.reject { |_, v| v.nil? }
    end

    class << self
      # Public: Initialize the Configuration Singleton. Must be called before any
      # access to `Configuration.instance` is used.
      #
      # conf_dir  - The String path to the directory the configuration can be found in
      # profile       - The String profile name that will be used to make AWS API calls
      # assume_role - The ARN of the role to assume when making AWS API calls
      # autoscaling_force_size
      #               -  Determines whether autoscaling should use configured values for
      #                  min/max/desired group size
      def init(conf_dir, profile, assume_role, autoscaling_force_size)
        instance = new(conf_dir, profile, assume_role, autoscaling_force_size)
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
        @groups_directory = absolute_path "iam/groups"
        @policy_document_directory = absolute_path "iam/roles/policy-documents"
        @policy_prefix = conf "iam.policies.prefix"
        @policy_suffix = conf "iam.policies.suffix"
        @policy_version = conf "iam.policies.version"
        @roles_directory = absolute_path "iam/roles"
        @static_policy_directory = absolute_path "iam/policies/static"
        @template_policy_directory = absolute_path "iam/policies/template"
        @users_directory = absolute_path "iam/users"
      end
    end

    # Public: Inner class that contains AutoScaling configuration options
    class AutoScalingConfig
      include Config

      attr_reader :groups_directory
      attr_reader :override_launch_config_on_sync
      attr_reader :static_policy_directory
      attr_reader :template_policy_directory
      attr_reader :force_size

      # Public: Constructor.
      def initialize(force_size = false)
        @groups_directory = absolute_path "autoscaling/groups"
        @override_launch_config_on_sync = conf "autoscaling.groups.override-launch-config-on-sync"
        @static_policy_directory = absolute_path "autoscaling/policies/static"
        @template_policy_directory = absolute_path "autoscaling/policies/templates"
        @force_size = force_size
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
        @includes_directory = absolute_path "route53/includes"
        @print_all_ignored = conf "route53.print-all-ignored"
        @zones_directory = absolute_path "route53/zones"
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
        @buckets_directory = absolute_path "s3/buckets"
        @cors_directory = absolute_path "s3/cors"
        @policies_directory = absolute_path "s3/policies"
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
        @groups_directory = absolute_path "security-groups/groups"
        @outbound_default_all_allowed = conf "security.outbound-default-all-allowed"
        @subnets_file = absolute_path "security-groups/subnets.json"
      end

    end

    # Public: Inner class that contains cloudfront configuration options
    class CloudFrontConfig
      include Config

      attr_reader :distributions_directory
      attr_reader :invalidations_directory

      def initialize
        @distributions_directory = absolute_path "cloudfront/distributions"
        @invalidations_directory = absolute_path "cloudfront/invalidations"
      end
    end

    # Public: Inner class that contains elb configuration options
    class ELBConfig
      include Config

      attr_reader :load_balancers_directory
      attr_reader :listeners_directory
      attr_reader :policies_directory

      def initialize
        @load_balancers_directory = absolute_path "elb/load-balancers"
        @listeners_directory = absolute_path "elb/listeners"
        @policies_directory = absolute_path "elb/policies"
      end
    end

    # Public: Inner class that contains vpc configuration options
    class VpcConfig
      include Config

      attr_reader :vpcs_directory
      attr_reader :subnets_directory
      attr_reader :route_tables_directory
      attr_reader :policies_directory
      attr_reader :network_acls_directory

      def initialize
        @vpcs_directory = absolute_path "vpc/vpcs"
        @subnets_directory = absolute_path "vpc/subnets"
        @route_tables_directory = absolute_path "vpc/route-tables"
        @policies_directory = absolute_path "vpc/policies"
        @network_acls_directory = absolute_path "vpc/network-acls"
      end
    end

    # Public: Inner class that contains kinesis configuration options
    class KinesisConfig
      include Config

      attr_reader :directory

      def initialize
        @directory = absolute_path "kinesis"
      end

    end

    # Public: Inner class that contains SQS configuration options
    class SQSConfig
      include Config

      attr_reader :queues_directory
      attr_reader :policies_directory

      def initialize
        @queues_directory =  absolute_path "sqs/queues"
        @policies_directory = absolute_path "sqs/policies"
      end
    end

    # Public: Inner class that contains EC2 configuration options
    class EC2Config
      include Config

      attr_reader :ebs_directory
      attr_reader :instances_directory
      attr_reader :ignore_unmanaged_instances
      attr_reader :user_data_directory
      attr_reader :default_image_id
      attr_reader :volume_mount_base
      attr_reader :volume_mount_start
      attr_reader :volume_mount_end

      def initialize
        @ebs_directory = absolute_path "ec2/ebs"
        @instances_directory = absolute_path "ec2/instances"
        @user_data_directory = absolute_path "ec2/user-data-scripts"
        @ignore_unmanaged_instances = conf "ec2.instances.ignore-unmanaged"
        @default_image_id = conf "ec2.instances.default-image-id"
        @volume_mount_base = conf "ec2.instances.volume-mounting.base"
        @volume_mount_start = conf "ec2.instances.volume-mounting.start"
        @volume_mount_end = conf "ec2.instances.volume-mounting.end"
      end
    end

  end
end
