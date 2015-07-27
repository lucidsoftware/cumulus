require "common/manager/Manager"
require "conf/Configuration"
require "security/loader/Loader"
require "security/models/SecurityGroupConfig"
require "security/models/SecurityGroupDiff"
require "util/Colors"

require "aws-sdk"

class SecurityGroups < Manager
  def initialize
    super()
    @ec2 = Aws::EC2::Client.new(region: Configuration.instance.region)
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
      config.populate(resource, sg_ids_to_names)

      puts "Writing #{resource.group_name} configuration to file..."
      File.open("#{groups_dir}/#{config.name}.json", "w") { |f| f.write(config.pretty_json) }
    end

    puts Colors.blue("IP addresses for inbound and outbound rules have been left as is in each individual security group, but we recommend that you name and group those IP addresses for maximum benefit.")
  end

  def resource_name
    "Security Group"
  end

  def local_resources
    @local_resources ||= Hash[Loader.groups.map { |local| [local.name, local] }]
  end

  def aws_resources
    @aws_resources ||= init_aws_resources
  end

  def sg_ids_to_names
    @sg_ids_to_names ||= Hash[aws_resources.map { |name, aws| [aws.group_id, aws.group_name] }]
  end

  def unmanaged_diff(aws)
    SecurityGroupDiff.unmanaged(aws)
  end

  def added_diff(local)
    SecurityGroupDiff.added(local)
  end

  def diff_resource(local, aws)
    local.diff(aws, sg_ids_to_names)
  end

  def create(local)
    result = @ec2.create_security_group({
      group_name: local.name,
      description: local.description,
      vpc_id: local.vpc_id,
    })
    security_group_id = result.group_id

    # make sure the hash exists before we try to update it
    if @sg_ids_to_names.nil?
      sg_ids_to_names
    end

    @sg_ids_to_names[security_group_id] = local.name
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
    if !remove.empty?
      puts Colors.blue("\tremoving #{options[:type]} rules...")
      options[:remove_action].call({
        group_id: security_group_id,
        ip_permissions: remove.map do |removed|
          permission = {
            ip_protocol: removed.protocol,
            from_port: removed.from,
            to_port: removed.to
          }

          # put the security group or subnets into the request
          if !removed.security_group.nil?
            permission[:user_id_group_pairs] = [
              {
                group_id: @sg_ids_to_names.key(removed.security_group)
              }
            ]
          else
            permission[:ip_ranges] = removed.subnets.map do |subnet|
              { cidr_ip: subnet }
            end
          end

          permission
        end
      })
    end

    if !add.empty?
      puts Colors.blue("\tadding #{options[:type]} rules...")
      options[:add_action].call({
        group_id: security_group_id,
        ip_permissions: add.map do |added|
          permission = {
            ip_protocol: added.protocol,
            from_port: added.from,
            to_port: added.to
          }

          # put the security group or subnets into the request
          if !added.security_group.nil?
            permission[:user_id_group_pairs] = [
              {
                group_id: @sg_ids_to_names.key(added.security_group)
              }
            ]
          else
            permission[:ip_ranges] = added.subnets.map do |subnet|
              { cidr_ip: subnet }
            end
          end

          permission
        end
      })
    end
  end

  def init_aws_resources
    aws = @ec2.describe_security_groups()
    Hash[aws.security_groups.map { |a| [a.group_name, a] }]
  end
end
