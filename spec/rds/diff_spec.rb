require "rds/RDSUtil"
require "rds/SingleChangeTest"

module Cumulus
  module Test
    module RDS
      describe Cumulus::RDS::Manager do
        context "The RDS module's diffing functionality" do
          it "should detect new instances defined locally" do
            instance_name = "not-in-aws"
            RDS::do_diff({
              local: {instances: [{name: instance_name, value: RDS::default_instance_attributes}]},
              aws: {describe_db_instances: {db_instances: []}},
            }) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq "RDS Instance #{instance_name} will be created."
            end
          end

          it "should detect new instances added in AWS" do
            instance_name = "not-local"
            RDS::do_diff({
              local: {instances: []},
              aws: {describe_db_instances: {db_instances: [RDS::aws_instance(instance_name)]}},
            }) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq "RDS Instance #{instance_name} is not managed by Cumulus."
            end
          end

          it "should detect changes made to the port" do
            SingleChangeTest.execute_diff(
              local: {"port" => DEFAULT_PORT - 1},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Port:",
                "\tAWS - #{DEFAULT_PORT}",
                "\tLocal - #{DEFAULT_PORT - 1}",
              ].join("\n")
            end
          end

          it "should detect changes made to the instance type" do
            SingleChangeTest.execute_diff(
              local: {"type" => SECONDARY_TYPE},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Type:",
                "\tAWS - #{DEFAULT_TYPE}",
                "\tLocal - #{SECONDARY_TYPE}",
              ].join("\n")
            end
          end

          it "should detect changes made to the engine" do
            SingleChangeTest.execute_diff(
              local: {"engine" => SECONDARY_ENGINE},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Engine:",
                "\tAWS - #{DEFAULT_ENGINE}",
                "\tLocal - #{SECONDARY_ENGINE}",
              ].join("\n")
            end
          end

          it "should detect changes made to the engine version" do
            SingleChangeTest.execute_diff(
              local: {"engine_version" => SECONDARY_ENGINE_VERSION},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Engine Version:",
                "\tAWS - #{DEFAULT_ENGINE_VERSION}",
                "\tLocal - #{SECONDARY_ENGINE_VERSION}",
              ].join("\n")
            end
          end

          it "should detect changes made to the storage type" do
            SingleChangeTest.execute_diff(
              local: {"storage_type" => SECONDARY_STORAGE_TYPE},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Storage Type:",
                "\tAWS - #{DEFAULT_STORAGE_TYPE}",
                "\tLocal - #{SECONDARY_STORAGE_TYPE}",
              ].join("\n")
            end
          end

          it "should detect changes made to the storage size" do
            SingleChangeTest.execute_diff(
              local: {"storage_size" => DEFAULT_STORAGE_SIZE - 1},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Storage Size:",
                "\tAWS - #{DEFAULT_STORAGE_SIZE}",
                "\tLocal - #{DEFAULT_STORAGE_SIZE - 1}",
              ].join("\n")
            end
          end

          it "should detect changes made to the username" do
            SingleChangeTest.execute_diff(
              local: {"master_username" => SECONDARY_USERNAME},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Username:",
                "\tAWS - #{DEFAULT_USERNAME}",
                "\tLocal - #{SECONDARY_USERNAME}",
              ].join("\n")
            end
          end

          it "should detect changes made to the db subnet group" do
            SingleChangeTest.execute_diff(
              local: {"subnet" => SECONDARY_SUBNET_GROUP},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Subnet:",
                "\tAWS - #{DEFAULT_SUBNET_GROUP}",
                "\tLocal - #{SECONDARY_SUBNET_GROUP}",
              ].join("\n")
            end
          end

          it "should detect changes made to the database name" do
            SingleChangeTest.execute_diff(
              local: {"database" => SECONDARY_DATABASE_NAME},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Database Name:",
                "\tAWS - #{DEFAULT_DATABASE_NAME}",
                "\tLocal - #{SECONDARY_DATABASE_NAME}",
              ].join("\n")
            end
          end

          it "should detect changes made to public access" do
            SingleChangeTest.execute_diff(
              local: {"public" => !DEFAULT_PUBLIC_FACING},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Public Facing:",
                "\tAWS - #{DEFAULT_PUBLIC_FACING}",
                "\tLocal - #{!DEFAULT_PUBLIC_FACING}",
              ].join("\n")
            end
          end

          it "should detect changes made to the backup period" do
            SingleChangeTest.execute_diff(
              local: {"backup_period" => DEFAULT_BACKUP_PERIOD - 1},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Backup:",
                "\tAWS - #{DEFAULT_BACKUP_PERIOD}",
                "\tLocal - #{DEFAULT_BACKUP_PERIOD - 1}",
              ].join("\n")
            end
          end

          it "should detect changes made to the backup window" do
            SingleChangeTest.execute_diff(
              local: {"backup_window" => SECONDARY_BACKUP_WINDOW},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Backup:",
                "\tAWS - #{DEFAULT_BACKUP_WINDOW}",
                "\tLocal - #{SECONDARY_BACKUP_WINDOW}",
              ].join("\n")
            end
          end

          it "should detect changes made to automatic upgrades" do
            SingleChangeTest.execute_diff(
              local: {"auto_upgrade" => !DEFAULT_AUTO_UPGRADE},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Upgrade:",
                "\tAWS - #{DEFAULT_AUTO_UPGRADE}",
                "\tLocal - #{!DEFAULT_AUTO_UPGRADE}",
              ].join("\n")
            end
          end

          it "should detect changes made to the upgrade window" do
            SingleChangeTest.execute_diff(
              local: {"upgrade_window" => SECONDARY_UPGRADE_WINDOW},
            ) do |diffs|
              expect(diffs.size).to eq 1
              expect(diffs.first.to_s).to eq [
                "Upgrade:",
                "\tAWS - #{DEFAULT_UPGRADE_WINDOW}",
                "\tLocal - #{SECONDARY_UPGRADE_WINDOW}",
              ].join("\n")
            end
          end

        end
      end
    end
  end
end
