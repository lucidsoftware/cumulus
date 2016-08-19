require "common/models/ListChange"
require "security/SecurityGroups"
require "rds/models/InstanceDiff"

module Cumulus
  module RDS
    class InstanceConfig
      attr_reader :name, :port, :type, :engine, :engine_version, :storage_type, :storage_size, :master_username, :security_groups, :subnet, :database, :public_facing, :backup_period, :backup_window, :auto_upgrade, :upgrade_window

      def initialize(name, json = nil)
        @name = name
        unless json.nil?
          @port = json["port"]
          @type = json["type"]
          @engine = json["engine"]
          @engine_version = json["engine_version"]
          @storage_type = json["storage_type"]
          @storage_size = json["storage_size"]
          @master_username = json["master_username"]
          @security_groups = json["security-groups"]
          @subnet = json["subnet"]
          @database = json["database"]
          @public_facing = json["public"]
          @backup_period = json["backup_period"]
          @backup_window = json["backup_window"]
          @auto_upgrade = json["auto_upgrade"]
          @upgrade_window = json["upgrade_window"].downcase
        end
      end

      def to_hash
        {
          "port" => @port,
          "type" => @type,
          "engine" => @engine,
          "engine_version" => @engine_version,
          "storage_type" => @storage_type,
          "storage_size" => @storage_size,
          "master_username" => @master_username,
          "security-groups" => @security_groups,
          "subnet" => @subnet,
          "database" => @database,
          "public" => @public_facing,
          "backup_period" => @backup_period,
          "backup_window" => @backup_window,
          "auto_upgrade" => @auto_upgrade,
          "upgrade_window" => @upgrade_window,
        }
      end

      def populate!(aws_instance)
        raise Exception.new("the rds instance (#{@name}) is still booting up.") if aws_instance[:db_instance_status] == "creating"
        @port = aws_instance[:endpoint][:port]
        @type = aws_instance[:db_instance_class].reverse.chomp("db.".reverse).reverse # remove the 'db.' that prefixes the string
        @engine = aws_instance[:engine]
        @engine_version = aws_instance[:engine_version]
        @storage_type = aws_instance[:storage_type]
        @storage_size = aws_instance[:allocated_storage]
        @master_username = aws_instance[:master_username]
        @security_groups = aws_instance[:vpc_security_groups].map(&:vpc_security_group_id).map { |id| SecurityGroups::id_security_groups[id].group_name }.sort
        @subnet = aws_instance[:db_subnet_group][:db_subnet_group_name]
        @database = aws_instance[:db_name]
        @public_facing = aws_instance[:publicly_accessible]
        @backup_period = aws_instance[:backup_retention_period]
        @backup_window = aws_instance[:preferred_backup_window]
        @auto_upgrade = aws_instance[:auto_minor_version_upgrade]
        @upgrade_window = aws_instance[:preferred_maintenance_window]
        self # return the instanceconfig
      end

      def diff(aws)
        diffs = Array.new

        if aws.port != @port
          diffs << InstanceDiff.new(InstanceChange::PORT, aws.port, @port)
        end

        if aws.type != @type
          diffs << InstanceDiff.new(InstanceChange::TYPE, aws.type, @type)
        end

        if aws.engine != @engine
          diffs << InstanceDiff.new(InstanceChange::ENGINE, aws.engine, @engine)
        end

        if aws.engine_version != @engine_version
          diffs << InstanceDiff.new(InstanceChange::ENGINE_VERSION, aws.engine_version, @engine_version)
        end

        if aws.storage_type != @storage_type
          diffs << InstanceDiff.new(InstanceChange::STORAGE_TYPE, aws.storage_type, @storage_type)
        end

        if aws.storage_size != @storage_size
          diffs << InstanceDiff.new(InstanceChange::STORAGE_SIZE, aws.storage_size, @storage_size)
        end

        if aws.master_username != @master_username
          diffs << InstanceDiff.new(InstanceChange::USERNAME, aws.master_username, @master_username)
        end

        if aws.security_groups != @security_groups
          changes = Common::ListChange::simple_list_diff(aws.security_groups, @security_groups)
          diffs << InstanceDiff.new(InstanceChange::SECURITY_GROUPS, aws.security_groups, @security_groups, changes)
        end

        if aws.subnet != @subnet
          diffs << InstanceDiff.new(InstanceChange::SUBNET, aws.subnet, @subnet)
        end

        if aws.database != @database
          diffs << InstanceDiff.new(InstanceChange::DATABASE, aws.database, @database)
        end

        if aws.public_facing != @public_facing
          diffs << InstanceDiff.new(InstanceChange::PUBLIC, aws.public_facing, @public_facing)
        end

        if aws.backup_period != @backup_period
          diffs << InstanceDiff.new(InstanceChange::BACKUP, aws.backup_period, @backup_period)
        end

        if aws.backup_window != @backup_window
          diffs << InstanceDiff.new(InstanceChange::BACKUP, aws.backup_window, @backup_window)
        end

        if aws.auto_upgrade != @auto_upgrade
          diffs << InstanceDiff.new(InstanceChange::UPGRADE, aws.auto_upgrade, @auto_upgrade)
        end

        if aws.upgrade_window != @upgrade_window
          diffs << InstanceDiff.new(InstanceChange::UPGRADE, aws.upgrade_window, @upgrade_window)
        end

        diffs
      end

    end
  end
end
