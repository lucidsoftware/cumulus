require "common/manager/Manager"
require "conf/Configuration"
require "elb/ELB"
require "elb/loader/Loader"
require "elb/models/LoadBalancerDiff"
require "security/SecurityGroups"
require "util/Colors"

require "aws-sdk"
require "json"

module Cumulus
  module ELB
    class Manager < Common::Manager

      include LoadBalancerChange

      require "aws_extensions/elb/PolicyDescription"
      Aws::ElasticLoadBalancing::Types::PolicyDescription.send(:include, AwsExtensions::ELB::PolicyDescription)

      def initialize
        super()
        @elb = ELB.client
      end

      def resource_name
        "Elastic Load Balancer"
      end

      def local_resources
        @local_resources ||= Hash[Loader.elbs.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= ELB::elbs
      end

      def unmanaged_diff(aws)
        LoadBalancerDiff.unmanaged(aws)
      end

      def added_diff(local)
        LoadBalancerDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      # Migrates all of the default load balancer policies to Cumulus versions
      def migrate_default_policies
        policies_dir = "#{@migration_root}/elb-default-policies"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(policies_dir)
          Dir.mkdir(policies_dir)
        end

        default_policies = ELB::default_policies
        default_policies.map do |policy_name, policy|
          puts "Processing #{policy_name}"

          cumulus_name = "Cumulus-#{policy_name}"
          json = JSON.pretty_generate(policy.to_cumulus_hash)

          File.open("#{policies_dir}/#{cumulus_name}.json", "w") { |f| f.write(json) }
        end
      end

      # Migrates all of the current AWS load balancers to Cumulus versions
      def migrate_elbs
        elbs_dir = "#{@migration_root}/elb-load-balancers"
        policies_dir ="#{@migration_root}/elb-policies"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(elbs_dir)
          Dir.mkdir(elbs_dir)
        end
        if !Dir.exists?(policies_dir)
          Dir.mkdir(policies_dir)
        end

        ELB::elbs.map do |elb_name, elb|
          puts "Migrating load balancer #{elb_name}"

          local_elb = LoadBalancerConfig.new(elb_name)
          tags = ELB::elb_tags(elb_name)
          attributes = ELB::elb_attributes(elb_name)
          local_elb.populate!(elb, tags, attributes)

          # Migrate the backend and listener policies if they do not already
          # exist locally and are not the default AWS policies
          listener_policies = local_elb.listeners.flat_map { |l| l.policies }
          backend_policies = local_elb.backend_policies.flat_map { |b| b.policy_names }

          (listener_policies + backend_policies).uniq.map do |policy_name|
            policy_file = "#{policies_dir}/#{policy_name}.json"
            # If it is not already migrated and not a default policy, create it
            if !File.file? policy_file
              if !ELB::default_policies.has_key? policy_name
                # Get the full policy description from the elb policies
                full_policy = ELB::elb_policies(elb_name)[policy_name]

                if full_policy.nil?
                  puts "Unable to migrate policy #{policy_name}"
                else
                  puts "Migrating policy #{policy_name}"
                  json = JSON.pretty_generate(full_policy.to_cumulus_hash)
                  File.open(policy_file, "w") { |f| f.write(json) }
                end
              end
            end
          end

          File.open("#{elbs_dir}/#{elb_name}.json", "w") { |f| f.write(local_elb.pretty_json) }
        end

      end

      def update(local, diffs)
        attributes_changed = false
        diffs.each do |diff|
          case diff.type
          when LISTENERS
            puts "Updating listeners..."
            update_listeners(local.name, diff.local, diff.aws, diff.listeners)
          when SUBNETS
            puts "Updating subnets..."
            update_subnets(local.name, diff.subnets)
          when SECURITY
            puts "Updating security groups..."
            update_security_groups(local.name, local.security_groups)
          when INTERNAL
            puts "AWS does not allow changing internal after creation"
          when TAGS
            puts "Updating tags..."
            update_tags(local.name, diff.tags)
          when INSTANCES
            if local.manage_instances != false
              puts "Updating managed instances..."
              update_instances(local.name, diff.instances.added, diff.instances.removed)
            end
          when HEALTH
            puts "Updating health check..."
            update_health_check(local.name, local.health_check)
          when BACKEND
            puts "Updating backend policies"
            update_backend_policies(local.name, diff.backend_policies.added, diff.backend_policies.removed, diff.backend_policies.modified)
          when CROSS
            puts "Updating cross zone load balancing"
            attributes_changed = true
          when LOG
            puts "Updating access log config"
            attributes_changed = true
          when DRAINING
            puts "Updating connection draining"
            attributes_changed = true
          when IDLE
            puts "Updating idle timeout"
            attributes_changed = true
          end
        end

        if attributes_changed
          update_attributes(local)
        end
      end

      def create(local)

        # Create the load balancer with listeners, subnets, security groups, scheme, and tags
        @elb.create_load_balancer({
          load_balancer_name: local.name,
          listeners: local.listeners.map(&:to_aws),
          subnets: local.subnets.map { |subnet| subnet.subnet_id },
          security_groups: local.security_groups.map do |sg_name|
            SecurityGroups::name_security_groups[sg_name].group_id
          end,
          scheme: if local.internal then "internal" end,
          tags: local.tags.to_a.map do |tagKey, tagValue|
            {
              key: tagKey,
              value: tagValue
            }
          end
        })

        # Set the policies for the attached listeners
        local.listeners.each do |listener|
          update_listener_policies(local.name, listener.load_balancer_port, listener.policies)
        end

        # Set the health check config
        update_health_check(local.name, local.health_check)

        # Set the attributes
        update_attributes(local)

        # Update the instances if they are managed
        if local.manage_instances != false
          update_instances(local.name, local.manage_instances)
        end

        # Set the backend policies
        backend_added = local.backend_policies.map do |backend_policy|
          LoadBalancerDiff::BackendChange.new(backend_policy.instance_port, nil, backend_policy.policy_names)
        end
        update_backend_policies(local.name, backend_added)

      end

      private

      # Internal - a helper for attempting to update a resource that may require a rollback
      #
      # resource_name - the name of the resource to print in the error messages
      # should_rollback - a boolean that indicates if a rollback should be attempted
      # update - a Proc that will cause the update to happen
      # rollback - a Proc that will undo whatever is necessary to return to a good state
      def update_rollback(resource_name, should_rollback, update, rollback)
        begin
          update.call()
        rescue => e
          puts Colors.red("There was an error updating #{resource_name}: #{e}")

          if should_rollback
            puts Colors.red("Attempting rollback of #{resource_name}...")
            begin
              rollback.call()
              puts Colors.orange("Rollback successful")
            rescue => rollback_error
              puts Colors.red("Unable to rollback #{resource_name}: #{rollback_error}")
              raise rollback_error
            end
          end

          raise e
        end
      end

      # Internal - update the listeners for a load balancer
      #
      # elb_name - the name of the load balancer to update
      # local_listeners - an array of the local ListenerConfig
      # aws_listeners - an array of the aws Aws::ElasticLoadBalancing::Types::ListenerDescription
      #   in case we need to roll back changes
      # listener_changes - a ListChange with details on what was changed
      def update_listeners(elb_name, local_listeners, aws_listeners, listener_changes)
        # First delete the removed listeners
        deleted_ports = listener_changes.removed.map { |port, _| port }
        deleted_listeners = aws_listeners.select { |l| deleted_ports.include? l.listener.load_balancer_port }

        if !deleted_ports.empty?
          @elb.delete_load_balancer_listeners({
            load_balancer_name: elb_name,
            load_balancer_ports: deleted_ports
          })
        end

        # Add the added listeners. If anything goes wrong, attempt a rollback (if listeners were deleted)
        added_ports = listener_changes.added.map { |port, _| port }
        added_listeners = local_listeners.select { |l| added_ports.include? l.load_balancer_port}
        if !added_listeners.empty?
          # create the listeners
          update_rollback("listeners", !deleted_ports.empty?,
            # update
            Proc.new {
              @elb.create_load_balancer_listeners({
                load_balancer_name: elb_name,
                listeners: added_listeners.map { |l| l.to_aws }
              })
            },
            # rollback
            Proc.new {
              @elb.create_load_balancer_listeners({
                load_balancer_name: elb_name,
                listeners: deleted_listeners.map { |l| l.listener }
              })

              deleted_listeners.each { |l| update_listener_policies(elb_name, l.listener.load_balancer_port, l.policy_names) }
            }
          )

          # set the policies of each created listener
          added_listeners.each { |listener| update_listener_policies(elb_name, listener.load_balancer_port, listener.policies) }
        end


        # For listeners where only the policy was modified, just set the listener policies
        policy_only_listeners = listener_changes.modified.select do |port, diffs|
          diffs.size == 1 && diffs.first.type == ListenerChange::POLICIES
        end

        policy_only_listeners.each do |port, diffs|
          listener = local_listeners.select { |l| port == l.load_balancer_port }.first
          update_listener_policies(elb_name, listener.load_balancer_port, listener.policies)
        end

        # For listeners with other changes, remove the old modified listeners and add the new ones, then update the listeners for each
        modified_ports = (listener_changes.modified.reject { |port, _| policy_only_listeners.has_key? port }).map { |port, _| port }
        modified_listeners = local_listeners.select { |l| modified_ports.include? l.load_balancer_port }

        if !modified_listeners.empty?
          @elb.delete_load_balancer_listeners({
            load_balancer_name: elb_name,
            load_balancer_ports: modified_ports
          })

          # recreate the modified listeners with the new attributes
          update_rollback("listeners", true,
            # update
            Proc.new {
              # create the listeners
              @elb.create_load_balancer_listeners({
                load_balancer_name: elb_name,
                listeners: modified_listeners.map { |l| l.to_aws }
              })
            },
            Proc.new {
              # create the listeners using the old config
              old_modified_listeners = aws_listeners.select { |l| modified_ports.include? l.listener.load_balancer_port }

              @elb.create_load_balancer_listeners({
                load_balancer_name: elb_name,
                listeners: old_modified_listeners.map { |l| l.listener }
              })

              # set the old policies
              old_modified_listeners.each { |l| update_listener_policies(elb_name, l.listener.load_balancer_port, l.policy_names) }
            }
          )

          # set the policies
          modified_listeners.each { |listener| update_listener_policies(elb_name, listener.load_balancer_port, listener.policies) }
        end
      end

      # Internal: update the listener policies for a listener
      #
      # elb_name - the name of the load balancer to update
      # port - the load balancer port for the listener to update policies for
      # policy_names - the names of the policies to set
      def update_listener_policies(elb_name, port, policy_names)
        # Make sure a policy exists for each policy on the listener
        policy_names.each do |policy_name|
          ensure_policy_exists(elb_name, policy_name)
        end

        @elb.set_load_balancer_policies_of_listener({
          load_balancer_name: elb_name,
          load_balancer_port: port,
          policy_names: policy_names
        })
      end

      # Internal - update the subnets for the load balancer
      #
      # elb_name - the name of the load balancer to update
      # subnet_changes - a ListChange with details on what was changed
      def update_subnets(elb_name, subnet_changes)
        # Since we cannot have multiple subnets in the same availability zone, we have to
        # detach subnets before we add them.
        detach_subnets = subnet_changes.removed.map { |subnet| subnet.subnet_id }
        if !detach_subnets.empty?
          @elb.detach_load_balancer_from_subnets({
            load_balancer_name: elb_name,
            subnets: detach_subnets
          })
        end

        # Attach subnets. If something goes wrong, attempt a rollback (if any subnets were removed)
        attach_subnets = subnet_changes.added.map { |subnet| subnet.subnet_id }
        if !attach_subnets.empty?
          update_rollback("subnets", !detach_subnets.empty?,
            # update
            Proc.new {
              @elb.attach_load_balancer_to_subnets({
                load_balancer_name: elb_name,
                subnets: attach_subnets
              })
            },
            # rollback
            Proc.new {
              @elb.attach_load_balancer_to_subnets({
                load_balancer_name: elb_name,
                subnets: detach_subnets
              })
            })
        end
      end

      # Internal: update the security groups for the load balancer
      #
      # elb_name - the name of the load balancer to update
      # security_groups - an array of security group ids tha will replace the existing config
      def update_security_groups(elb_name, security_groups)
        @elb.apply_security_groups_to_load_balancer({
          load_balancer_name: elb_name,
          security_groups: security_groups.map do |sg_name|
            SecurityGroups::name_security_groups[sg_name].group_id
          end
        })
      end

      # Internal: update the tags for the load balancer
      #
      # elb_name - the name of the load balancer to update
      # tag_changes - a ListChange describing what was modified
      def update_tags(elb_name, tag_changes)

        # First remove the tags that were deleted
        if !tag_changes.removed.empty?
          @elb.remove_tags({
            load_balancer_names: [elb_name],
            tags: tag_changes.removed.map { |t| { key: t.key } }
          })
        end

        # Update and add the other tags
        update_tags = (tag_changes.added + tag_changes.modified).map do |t|
          {
            key: t.key,
            value: t.local
          }
        end
        if !update_tags.empty?
          update_rollback("tags", !tag_changes.removed.empty?,
            # update
            Proc.new {
              @elb.add_tags({
                load_balancer_names: [elb_name],
                tags: update_tags
              })
            },
            # rollback
            Proc.new {
              @elb.add_tags({
                load_balancer_names: [elb_name],
                tags: tag_changes.removed.map do |t|
                  {
                    key: t.key,
                    value: t.aws
                  }
                end
              })
            })
        end
      end

      # Internal: update the managed instances for a load balancer
      #
      # elb_name - then name of the load balancer to update
      # instances_added - the array of instances that were added
      # instances_removed - the array of instances that were removed
      def update_instances(elb_name, instances_added, instances_removed = [])

        # deregister instances that were removed
        if !instances_removed.empty?
          @elb.deregister_instances_from_load_balancer({
            load_balancer_name: elb_name,
            instances: instances_removed.map do |i|
              {
                instance_id: i
              }
            end
          })
        end

        # register instances that were added
        if !instances_added.empty?
          @elb.register_instances_with_load_balancer({
            load_balancer_name: elb_name,
            instances: instances_added.map do |i|
              {
                instance_id: i
              }
            end
          })
        end
      end

      # Internal: update the health check config
      #
      # elb_name - the name of the load balancer to update
      # health_check - the HealthCheckConfig to update with
      def update_health_check(elb_name, health_check)
        @elb.configure_health_check({
          load_balancer_name: elb_name,
          health_check: health_check.to_aws
        })
      end

      # Internal: update the backend policies
      #
      # elb_name - the name of the load balancer to update
      # backend_added - the backend policies to be added
      # backend_removed - the backend policies to be removed
      # backend_modified - the backend policies to be modified
      def update_backend_policies(elb_name, backend_added, backend_removed = [], backend_modified = [])

        # Update the created and modified policies
        (backend_added + backend_modified).each do |backend|
          # First make sure each policy exists
          backend.local_policies.each do |policy_name|
            ensure_policy_exists(elb_name, policy_name)
          end

          @elb.set_load_balancer_policies_for_backend_server({
            load_balancer_name: elb_name,
            instance_port: backend.port,
            policy_names: backend.local_policies
          })
        end

        # Update the deleted ones by setting policy names to []
        backend_removed.each do |backend|
          @elb.set_load_balancer_policies_for_backend_server({
            load_balancer_name: elb_name,
            instance_port: backend.port,
            policy_names: []
          })
        end
      end

      # Internal: Updates all of the other attributes for an ELB:
      # cross-zone load balancing, access log config, connection draining, idle timeout
      #
      # local_config - the full local config for the elb
      def update_attributes(local_config)
        @elb.modify_load_balancer_attributes({
          load_balancer_name: local_config.name,
          load_balancer_attributes: {
            cross_zone_load_balancing: {
              enabled: local_config.cross_zone
            },
            access_log: if local_config.access_log then local_config.access_log.to_aws end,
            connection_draining: {
              enabled: local_config.connection_draining != false,
              timeout: if local_config.connection_draining != false then local_config.connection_draining end
            },
            connection_settings: {
              idle_timeout: local_config.idle_timeout
            }
          }
        })
      end

      # Internal: Makes sure the passed in policy exists on the load balancer
      #   so that it can be used in listeners and back ends.  Does not update the policy
      #
      # elb_name - the name of the elb to create the policy for
      # policy_name - The policy name. If the policy does not exist it will be loaded from local config
      #   and then created for this elb
      def ensure_policy_exists(elb_name, policy_name)
        existing_policies = ELB::elb_policies(elb_name)

        if !existing_policies[policy_name]
          local_policy = (Loader.policy(policy_name) rescue nil)
          if local_policy.nil?
            raise "#{policy_name} is not already defined on the load balancer and not defined locally"
          end

          @elb.create_load_balancer_policy({
            load_balancer_name: elb_name,
            policy_name: local_policy.policy_name,
            policy_type_name: local_policy.policy_type_name,
            policy_attributes: local_policy.policy_attribute_descriptions.map(&:to_h)
          })
        end
      end

    end
  end
end
