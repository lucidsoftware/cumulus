require "rds/RDS"
require "rds/loader/Loader"
require "common/manager/Manager"
require "rds/models/InstanceDiff"
require "conf/Configuration"
require "io/console"

module Cumulus
  module RDS
    class Manager < Common::Manager
      def resource_name
        "RDS Database Instance"
      end

      def local_resources
        @local_resources ||= Hash[Loader.instances.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= RDS::named_instances
      end

      def unmanaged_diff(aws)
        InstanceDiff.unmanaged(aws)
      end

      def added_diff(local)
        InstanceDiff.added(local)
      end

      def diff_resource(local, aws)
        puts Colors.blue("Processing #{local.name}...")
        cumulus_version = InstanceConfig.new(local.name).populate!(aws)
        local.diff(cumulus_version)
      end

      def migrate
        puts Colors.blue("Will migrate #{RDS.instances.length} instances")

        # Create the directories
        rds_dir = "#{@migration_root}/rds"
        instances_dir = "#{rds_dir}/instances"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(rds_dir)
          Dir.mkdir(rds_dir)
        end
        if !Dir.exists?(instances_dir)
          Dir.mkdir(instances_dir)
        end

        RDS.named_instances.each do |name, instance|
          puts "Migrating #{name}..."

          cumulus_instance = InstanceConfig.new(name).populate!(instance)

          json = JSON.pretty_generate(cumulus_instance.to_hash)
          File.open("#{instances_dir}/#{name}.json", "w") { |f| f.write(json) }
        end
      end

      def update(local, diffs)
        aws_instance = RDS::named_instances[local.name]
        client = Aws::RDS::Client.new(Configuration.instance.client)

        all_changes = diffs.map do |diff|
          case diff.type
          when InstanceChange::ENGINE,
               InstanceChange::USERNAME,
               InstanceChange::SUBNET,
               InstanceChange::DATABASE,
               InstanceChange::STORAGE_TYPE
            puts Colors.red("Cannot change #{diff.asset_type}")
            # no change for this diff, ignore it
            nil
          when InstanceChange::PORT
            puts "Updating the database port number..."
            {db_port_number: local.port}
          when InstanceChange::TYPE
            puts "Updating the database instance type..."
            {db_instance_class: "db." + local.type}
          when InstanceChange::ENGINE_VERSION
            puts "Updating the engine version..."
            {engine_version: local.engine_version}
          when InstanceChange::STORAGE_SIZE
            puts "Updating the allocated storage..."
            {allocated_storage: local.storage_size}
          when InstanceChange::SECURITY_GROUPS
            puts "Updating the security groups..."
            security_group_ids = local.security_groups.map do |sg|
              # TODO: once the db subnet config is created, find the security group id based on the vpc in that subnet.
              # right now, if security groups from different vpc have the same name, this might not return the right id.
              sg_id = SecurityGroups.vpc_security_group_id_names.values.inject(:merge).key(sg)
              if sg_id.nil?
                raise Exception.new("security group #{sg} does not exist")
              end
              sg_id
            end
            {vpc_security_group_ids: security_group_ids}
          when InstanceChange::PUBLIC
            if local.public_facing
              puts "making the database public..."
            else
              puts "blocking the database from the public..."
            end
            {publicly_accessible: local.public_facing}
          when InstanceChange::BACKUP
            puts "Updating the backup preferences..."
            {preferred_backup_window: local.backup_window, backup_retention_period: local.backup_period}
          when InstanceChange::UPGRADE
            puts "Updating the upgrade preferences..."
            {preferred_maintenance_window: local.upgrade_window, auto_minor_version_upgrade: local.auto_upgrade}
          end
        end.reject {|v| v.nil?}.reduce(&:merge)

        # make all the updates in the same call
        client.modify_db_instance({db_instance_identifier: local.name, apply_immediately: true}.merge(all_changes))
      end

      def create(local)
        errors = Array.new

        if local.name.nil?
          errors << "instance name is required"
        end

        if local.type.nil?
          errors << "instance type is required"
        end

        if local.engine.nil?
          errors << "database engine is required"
        end

        unless errors.empty?
          puts Colors.red("Could not create #{local.name}:")
          errors.each { |e| puts Colors.red("\t#{e}")}
          exit StatusCodes::EXCEPTION
        end

        master_password = unless local.master_username.nil?
          # prompt for the user's password (discreetly)
          print "enter a password for #{local.master_username}: "
          password = STDIN.noecho(&:gets).chomp
          puts "\n"
          password
        else
          nil
        end

        security_group_ids = local.security_groups.map do |sg|
          # TODO: once the db subnet config is created, find the security group id based on the vpc in that subnet.
          # right now, if security groups from different vpc have the same name, this might not return the right id.
          sg_id = SecurityGroups.vpc_security_group_id_names.values.inject(:merge).key(sg)
          if sg_id.nil?
            raise Exception.new("security group #{sg} does not exist")
          end
          sg_id
        end

        client = Aws::RDS::Client.new(Configuration.instance.client)

        client.create_db_instance({
          db_name: local.database,
          db_instance_identifier: local.name, # required
          allocated_storage: local.storage_size,
          db_instance_class: "db." + local.type, # required
          engine: local.engine, # required
          master_username: local.master_username,
          master_user_password: master_password,
          vpc_security_group_ids: security_group_ids,
          db_subnet_group_name: local.subnet,
          preferred_maintenance_window: local.upgrade_window,
          backup_retention_period: local.backup_period,
          preferred_backup_window: local.backup_window,
          port: local.port,
          engine_version: local.engine_version,
          auto_minor_version_upgrade: local.auto_upgrade,
          publicly_accessible: local.public_facing,
          storage_type: local.storage_type,
        }.reject { |k, v| v.nil? })

      end

    end
  end
end
