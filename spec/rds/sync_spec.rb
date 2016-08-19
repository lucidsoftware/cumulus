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
              expect(create.arguments[0]).to eq ({
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
          end

          it "should update the instance type" do
          end

          it "should update the engine" do
          end

          it "should update the engine version" do
          end

          it "should update the storage type" do
          end

          it "should update the storage size" do
          end

          it "should update the username" do
          end

          it "should update the db subnet group" do
          end

          it "should update the database name" do
          end

          it "should update public access" do
          end

          it "should update the backup period" do
          end

          it "should update the backup window" do
          end

          it "should update automatic upgrades" do
          end

          it "should update the upgrade window" do
          end

        end
      end
    end
  end
end
