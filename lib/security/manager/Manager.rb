require "common/manager/Manager"
require "conf/Configuration"
require "security/loader/Loader"
require "security/models/SecurityGroupConfig"
require "security/models/SecurityGroupDiff"
require "security/SecurityGroups"
require "util/Colors"

require "aws-sdk"
require "json"

module Cumulus
  module SecurityGroups
    class Manager < Common::Manager
      def initialize
        super()
        @ec2 = Aws::EC2::Client.new(Configuration.instance.client)
      end

      # Public: Migrate AWS Security Groups to Cumulus configuration.
      def migrate
        groups_dir = "#{@migration_root}/groups"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(groups_dir)
          Dir.mkdir(groups_dir)
        end

        aws_resources.each_value do |resource|
          puts "Processing #{resource.group_name}..."
          config = SecurityGroupConfig.new(resource.group_name)
          config.populate!(resource)

          puts "Writing #{resource.group_name} configuration to file..."
          File.open("#{groups_dir}/#{config.name}.json", "w") { |f| f.write(config.pretty_json) }
        end

        File.open("#{@migration_root}/subnets.json", "w") do |f|
          f.write(JSON.pretty_generate({
            "all" => ["0.0.0.0/0"]
          }))
        end

        puts Colors.blue("IP addresses for inbound and outbound rules have been left as is in each individual security group, except in the case of 0.0.0.0/0.")
        puts Colors.blue("0.0.0.0/0 has been renamed to 'all' and is referenced as such in security group definitions.")
        puts Colors.blue("See subnets.json to see the definition of the 'all' subnet group.")
      end

      def resource_name
        "Security Group"
      end

      def local_resources
        @local_resources ||= Hash[Loader.groups.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= SecurityGroups::name_security_groups
      end

      def unmanaged_diff(aws)
        SecurityGroupDiff.unmanaged(aws)
      end

      def added_diff(local)
        SecurityGroupDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      def create(local)
        result = @ec2.create_security_group({
          group_name: local.name,
          description: local.description,
          vpc_id: local.vpc_id,
        })
        security_group_id = result.group_id

        SecurityGroups::sg_id_names[security_group_id] = local.name
        update_tags(security_group_id, local.tags, {})
        update_inbound(security_group_id, local.inbound, [])

        outbound_remove = if Configuration.instance.security.outbound_default_all_allowed and local.outbound.empty?
          []
        else
          [RuleConfig.allow_all]
        end
        update_outbound(security_group_id, local.outbound, outbound_remove)
      end

      def update(local, diffs)
        diffs_by_type = diffs.group_by(&:type)

        if diffs_by_type.include?(SecurityGroupChange::VPC_ID)
          puts "\tUnfortunately, you can't change out the vpc id. You'll have to manually manage any dependencies on this security group, delete the security group, and recreate the security group with Cumulus if you'd like to change the vpc id."
        elsif diffs_by_type.include?(SecurityGroupChange::DESCRIPTION)
          puts "\tUnfortunately, AWS's SDK does not allow updating the description."
        else
          diffs.each do |diff|
            case diff.type
            when SecurityGroupChange::TAGS
              update_tags(diff.aws.group_id, diff.tags_to_add, diff.tags_to_remove)
            when SecurityGroupChange::INBOUND
              update_inbound(diff.aws.group_id, diff.added_inbounds, diff.removed_inbounds)
            when SecurityGroupChange::OUTBOUND
              update_outbound(diff.aws.group_id, diff.added_outbounds, diff.removed_outbounds)
            end
          end
        end
      end

      private

      # Internal: Update the tags associated with a security group.
      #
      # security_group_id - the id of the security group to update
      # add               - the tags to add (expects a hash of key value pairs)
      # remove            - the tags to remove (expects a hash of key value pairs)
      def update_tags(security_group_id, add, remove)
        if !add.empty?
          puts Colors.blue("\tadding tags...")
          @ec2.create_tags({
            resources: [security_group_id],
            tags: add.map { |k, v| { key: k, value: v } }
          })
        end
        if !remove.empty?
          puts Colors.blue("\tremoving tags...")
          @ec2.delete_tags({
            resources: [security_group_id],
            tags: remove.map { |k, v| { key: k, value: v } }
          })
        end
      end

      # Internal: Update the inbound rules associated with a security group.
      #
      # security_group_id - the id of the security group
      # add               - the inbound rules to associate with the security group
      # remove            - the inbound rules to dissociate from the security group
      def update_inbound(security_group_id, add, remove)
        update_rules(
          security_group_id,
          add,
          remove,
          {
            :type => "inbound",
            :add_action => @ec2.method(:authorize_security_group_ingress),
            :remove_action => @ec2.method(:revoke_security_group_ingress)
          }
        )
      end

      # Internal: Update the outbound rules associated with a security group.
      #
      # security_group_id - the id of the security group
      # add               - the outbound rules to associate with the security group
      # remove            - the outbound rules to associate with the security group
      #
      def update_outbound(security_group_id, add, remove)
        update_rules(
          security_group_id,
          add,
          remove,
          {
            :type => "outbound",
            :add_action => @ec2.method(:authorize_security_group_egress),
            :remove_action => @ec2.method(:revoke_security_group_egress)
          }
        )
      end

      # Internal: Update rules associated with a security group. Called by inbound
      # and outbound.
      #
      # security_group_id - the id of the security group
      # add               - the rules to associate with the security group
      # remove            - the rules to remove from the security group
      # options           - a hash containing options about the operation to run. Should contain:
      #   - type              - a string representing the type of rules to process
      #   - add_action        - the client method to call to add rules
      #   - remove_action     - the client method to call to remove rules
      def update_rules(security_group_id, add, remove, options)
        if !add.empty?
          puts Colors.blue("\tadding #{options[:type]} rules...")
          options[:add_action].call({
            group_id: security_group_id,
            ip_permissions: add.map do |added|
              missing_group = added.security_groups.find { |s| !SecurityGroups::sg_id_names.value? s }
              if missing_group
                puts Colors.red("\t\tNo such security group: #{missing_group}. Security group not added.")
              end

              added.to_aws
            end
          })
        end

        if !remove.empty?
          puts Colors.blue("\tremoving #{options[:type]} rules...")
          options[:remove_action].call({
            group_id: security_group_id,
            ip_permissions: remove.map do |removed|
              missing_group = removed.security_groups.find { |s| !SecurityGroups::sg_id_names.value? s }
              if missing_group
                puts Colors.red("\t\tNo such security group: #{missing_group}. Security group not removed.")
              end

              removed.to_aws
            end
          })
        end

      end
    end
  end
end
