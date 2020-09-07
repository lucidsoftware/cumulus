require "rds/RDSUtil"
require "rds/SingleChangeTest"

module Cumulus
  module Test
    module RDS
      describe Cumulus::RDS::Manager do
        context "The SQS module's syncing functionality" do
          it "should correctly create a new instance that's defined locally" do
            instance_name = "not-in-aws"
            RDS::client_spy
            RDS::do_sync({
              local: {instances: [{name: instance_name, value: RDS::default_instance_attributes}]},
              aws: {describe_db_instances: {db_instances: []}},
            }) do |client|
              create = client.spied_method(:create_db_instance)
              expect(create.num_calls).to eq 1
              expect(create.arguments.first).to eq ({
                db_name: DEFAULT_DATABASE_NAME,
                db_instance_identifier: instance_name,
                allocated_storage: DEFAULT_STORAGE_SIZE,
                db_instance_class: "db." + DEFAULT_TYPE,
                engine: DEFAULT_ENGINE,
                master_username: DEFAULT_USERNAME,
                master_user_password: DEFAULT_PASSWORD,
                vpc_security_group_ids: Array.new,
                db_subnet_group_name: DEFAULT_SUBNET_GROUP,
                preferred_maintenance_window: DEFAULT_UPGRADE_WINDOW,
                backup_retention_period: DEFAULT_BACKUP_PERIOD,
                preferred_backup_window: DEFAULT_BACKUP_WINDOW,
                port: DEFAULT_PORT,
                engine_version: DEFAULT_ENGINE_VERSION,
                auto_minor_version_upgrade: DEFAULT_AUTO_UPGRADE,
                publicly_accessible: DEFAULT_PUBLIC_FACING,
                storage_type: DEFAULT_STORAGE_TYPE,
              })
            end
          end

          it "should not delete instances added in AWS" do
            instance_name = "not-local"
            RDS::client_spy
            RDS::do_sync({
              local: {instances: []},
              aws: {describe_db_instances: {db_instances: [RDS::aws_instance(instance_name)]}},
            }) do |client|
              # no calls were made to change anything
              expect(client.method_calls.size).to eq 2 # one call to :stub responses, and one call to :describe_db_instances (for diff)
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
            end
          end

          it "should update the port" do
            SingleChangeTest.execute_sync(
              local: {"port" => DEFAULT_PORT - 1},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                db_port_number: DEFAULT_PORT - 1
              })
            end
          end

          it "should update the instance type" do
            SingleChangeTest.execute_sync(
              local: {"type" => SECONDARY_TYPE},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                db_instance_class: "db." + SECONDARY_TYPE
              })
            end
          end

          it "should update the engine" do
            SingleChangeTest.execute_sync(
              local: {"engine" => SECONDARY_ENGINE},
            ) do |client|
              expect(client.method_calls.size).to eq 2
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
            end
          end

          it "should update the engine version" do
            SingleChangeTest.execute_sync(
              local: {"engine_version" => SECONDARY_ENGINE_VERSION},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                engine_version: SECONDARY_ENGINE_VERSION
              })
            end
          end

          it "should update the storage type" do
            SingleChangeTest.execute_sync(
              local: {"storage_type" => SECONDARY_STORAGE_TYPE},
            ) do |client|
              expect(client.method_calls.size).to eq 2
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
            end
          end

          it "should update the storage size" do
            SingleChangeTest.execute_sync(
              local: {"storage_size" => DEFAULT_STORAGE_SIZE - 1},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                allocated_storage: DEFAULT_STORAGE_SIZE - 1
              })
            end
          end

          it "should update the username" do
            SingleChangeTest.execute_sync(
              local: {"master_username" => SECONDARY_USERNAME},
            ) do |client|
              expect(client.method_calls.size).to eq 2
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
            end
          end

          it "should update the db subnet group" do
            SingleChangeTest.execute_sync(
              local: {"subnet" => SECONDARY_SUBNET_GROUP},
            ) do |client|
              expect(client.method_calls.size).to eq 2
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
            end
          end

          it "should update the database name" do
            SingleChangeTest.execute_sync(
              local: {"database" => SECONDARY_DATABASE_NAME},
            ) do |client|
              expect(client.method_calls.size).to eq 2
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
            end
          end

          it "should update public access" do
            SingleChangeTest.execute_sync(
              local: {"public" => !DEFAULT_PUBLIC_FACING},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                publicly_accessible: !DEFAULT_PUBLIC_FACING
              })
            end
          end

          it "should update the backup period" do
            SingleChangeTest.execute_sync(
              local: {"backup_period" => DEFAULT_BACKUP_PERIOD - 1},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                preferred_backup_window: DEFAULT_BACKUP_WINDOW,
                backup_retention_period: DEFAULT_BACKUP_PERIOD - 1
              })
            end
          end

          it "should update the backup window" do
            SingleChangeTest.execute_sync(
              local: {"backup_window" => SECONDARY_BACKUP_WINDOW},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                preferred_backup_window: SECONDARY_BACKUP_WINDOW,
                backup_retention_period: DEFAULT_BACKUP_PERIOD
              })
            end
          end

          it "should update automatic upgrades" do
            SingleChangeTest.execute_sync(
              local: {"auto_upgrade" => !DEFAULT_AUTO_UPGRADE},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                preferred_maintenance_window: DEFAULT_UPGRADE_WINDOW,
                auto_minor_version_upgrade: !DEFAULT_AUTO_UPGRADE
              })
            end
          end

          it "should update the upgrade window" do
            SingleChangeTest.execute_sync(
              local: {"upgrade_window" => SECONDARY_UPGRADE_WINDOW},
            ) do |client|
              expect(client.method_calls.size).to eq 3
              expect(client.spied_method(:stub_responses).nil?).to eq false
              expect(client.spied_method(:describe_db_instances).nil?).to eq false
              update = client.spied_method(:modify_db_instance)
              expect(update.nil?).to eq false
              expect(update.num_calls).to eq 1
              expect(update.arguments.first).to eq ({
                db_instance_identifier: "cumulus-test-instance",
                apply_immediately: true,
                preferred_maintenance_window: SECONDARY_UPGRADE_WINDOW,
                auto_minor_version_upgrade: DEFAULT_AUTO_UPGRADE
              })
            end
          end

        end
      end
    end
  end
end
