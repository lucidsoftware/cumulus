require "conf/Configuration"
require "mocks/MockedConfiguration"
Cumulus::Configuration.send :include, Cumulus::Test::MockedConfiguration

require "common/BaseLoader"
require "mocks/MockedLoader"
Cumulus::Common::BaseLoader.send :include, Cumulus::Test::MockedLoader

require "common/manager/Manager"
require "util/ManagerUtil"
Cumulus::Common::Manager.send :include, Cumulus::Test::ManagerUtil

require "util/StatusCodes"
require "mocks/MockedStatusCodes"
Cumulus::StatusCodes.send :include, Cumulus::Test::MockedStatusCodes

require "aws-sdk"
require "json"
require "rds/manager/Manager"
require "rds/RDS"
require "util/DeepMerge"


module Cumulus
  module Test
    # Monkey patch Cumulus::RDS such that the cached values from the AWS client
    # can be reset between tests.
    module ResetRDS
      def self.included(base)
        base.instance_eval do
          def reset_instances
            @instances = nil
          end
        end
      end
    end

    module RDS
      @instances_directory = "/mocked/rds/instances"
      @default_instance_name = "test-instance"

      DEFAULT_PORT = 3306
      DEFAULT_TYPE = "t2.micro"
      SECONDARY_TYPE = "m4.large"
      DEFAULT_ENGINE = "mysql"
      SECONDARY_ENGINE = "aurora"
      DEFAULT_ENGINE_VERSION = "5.6.27"
      SECONDARY_ENGINE_VERSION = "6.0.0"
      DEFAULT_STORAGE_TYPE = "gp2"
      SECONDARY_STORAGE_TYPE = "standard"
      DEFAULT_STORAGE_SIZE = 5
      DEFAULT_USERNAME = "testing"
      SECONDARY_USERNAME = "diffme"
      DEFAULT_SUBNET_GROUP = "default"
      SECONDARY_SUBNET_GROUP = "secondary"
      DEFAULT_DATABASE_NAME = "testdb"
      SECONDARY_DATABASE_NAME = "seconddb"
      DEFAULT_PUBLIC_FACING = false
      DEFAULT_BACKUP_PERIOD = 7
      DEFAULT_BACKUP_WINDOW = "02:30-03:00"
      SECONDARY_BACKUP_WINDOW = "01:00-02:30"
      DEFAULT_AUTO_UPGRADE = true
      DEFAULT_UPGRADE_WINDOW = "mon:03:27-mon:03:57"
      SECONDARY_UPGRADE_WINDOW = "tue:03:30-tue:04:00"


      @default_instance_attributes = {
        "port" => DEFAULT_PORT,
        "type" => DEFAULT_TYPE,
        "engine" => DEFAULT_ENGINE,
        "engine_version" => DEFAULT_ENGINE_VERSION,
        "storage_type" => DEFAULT_STORAGE_TYPE,
        "storage_size" => DEFAULT_STORAGE_SIZE,
        "master_username" => DEFAULT_USERNAME,
        "security-groups" => [

        ],
        "subnet" => DEFAULT_SUBNET_GROUP,
        "database" => DEFAULT_DATABASE_NAME,
        "public" => DEFAULT_PUBLIC_FACING,
        "backup_period" => DEFAULT_BACKUP_PERIOD,
        "backup_window" => DEFAULT_BACKUP_WINDOW,
        "auto_upgrade" => DEFAULT_AUTO_UPGRADE,
        "upgrade_window" => DEFAULT_UPGRADE_WINDOW,
      }

      @default_aws_instance_attributes = {
        endpoint: {
          port: DEFAULT_PORT,
        },
        db_instance_class: "db." + DEFAULT_TYPE,
        engine: DEFAULT_ENGINE,
        engine_version: DEFAULT_ENGINE_VERSION,
        storage_type: DEFAULT_STORAGE_TYPE,
        allocated_storage: DEFAULT_STORAGE_SIZE,
        master_username: DEFAULT_USERNAME,
        vpc_security_groups: [

        ],
        db_subnet_group: {
          db_subnet_group_name: DEFAULT_SUBNET_GROUP
        },
        db_name: DEFAULT_DATABASE_NAME,
        publicly_accessible: DEFAULT_PUBLIC_FACING,
        backup_retention_period: DEFAULT_BACKUP_PERIOD,
        preferred_backup_window: DEFAULT_BACKUP_WINDOW,
        auto_minor_version_upgrade: DEFAULT_AUTO_UPGRADE,
        preferred_maintenance_window: DEFAULT_UPGRADE_WINDOW,
      }

      # Public: Returns a Hash containing default instance attributes for a local
      # instance definition with values overridden by the Hash passed in.
      #
      # overrides - optionally provide a Hash that will override default
      #   attributes
      def self.default_instance_attributes(overrides = nil)
        Util::DeepMerge.deep_merge(@default_instance_attributes, overrides)
      end

      def self.do_diff(config, &test)
        self.prepare_test(config)

        # get the diffs and call the tester to determine the result of the test
        manager = Cumulus::RDS::Manager.new
        diffs = manager.diff_strings
        test.call(diffs)
      end

      # Public: Returns a mocked rds instance object similar to what the aws client would return
      def self.aws_instance(name, overrides = nil)
        overrides = if overrides.nil?
          {db_instance_identifier: name}
        else
          {db_instance_identifier: name}.merge(overrides)
        end
        Util::DeepMerge.deep_merge(@default_aws_instance_attributes, overrides)
      end

      private

      def self.prepare_test(config)
        self.reset

        # stub out local queues
        if config[:local][:instances]
          Cumulus::Common::BaseLoader.stub_directory(
            @instances_directory, config[:local][:instances]
          )
        end

        # stub out aws responses
        config[:aws].map do |call, value|
          if value
            Cumulus::RDS::client.stub_responses(call, value)
          else
            Cumulus::RDS::client.stub_responses(call)
          end
        end
      end

      # Public: Reset the SQS module in between tests
      def self.reset
        Cumulus::Configuration.stub

        # reset Cumulus::RDS to forget cached aws resources
        if !Cumulus::RDS.respond_to? :reset_instances
          Cumulus::RDS.send :include, Cumulus::Test::ResetRDS
        end

        Cumulus::RDS::reset_instances
      end
    end
  end
end
