require "common/models/Diff"
require "iam/migration/PolicyUnifier"
require "iam/models/IamDiff"
require "util/Colors"

require 'uri'

module Cumulus
  module IAM
    # Internal: Represents the manager of a type of IamResource. Base class for
    # groups, roles, and users.
    class IamResource
      @@diff = Proc.new do |name, diffs|
        if diffs.size > 0
          if diffs.size == 1 and (diffs[0].type == Common::DiffChange::ADD or
            diffs[0].type == Common::DiffChange::UNMANAGED)
            puts diffs[0]
          else
            puts "#{name} has the following changes:"
            diffs.each do |diff|
              diff_string = diff.to_s.lines.map { |s| "\t#{s}" }.join
              puts diff_string
            end
          end
        end
      end

      # =====================================================
      # Methods to be overridden
      # =====================================================
      # Public: Get the local resources
      #
      # Returns an array of resources
      def local_resources
        nil
      end

      # Public: Get one local resource
      #
      # name - the name of the resource to load
      #
      # Returns one local resource
      def one_local(name)
        nil
      end

      # Public: Get resources from AWS
      #
      # Returns an array of resources from AWS
      def aws_resources
        nil
      end

      # Public: Create a resource in AWS
      #
      # difference - the Diff object that contains the local differences
      #
      # Returns the created resource
      def create(difference)
        nil
      end

      # Public: Create an empty config object
      #
      # Returns the created config object
      def empty_config
        nil
      end

      # Public: When migrating, provide a config with any resource type specific
      # data.
      #
      # configs_to_aws - an array of arrays where each inner array's first element
      #                  is the configuration generated so far, and the second
      #                  element is the corresponding aws resource
      def migrate_additional(configs_to_aws)
      end

      # =====================================================
      # End methods to be overridden
      # =====================================================

      # Public: Constructor
      #
      # iam - the IAM client to use
      def initialize(iam)
        @iam = iam
        @migration_root = "generated"
      end

      # Public: Print out the diff between the local configuration and the IAMS
      # in AWS
      def diff
        each_difference(local_resources, true, &@@diff)
      end

      # Public: Print out the diff between local configuration and AWS for one
      # resource
      #
      # name - the name of the resource to diff
      def diff_one(name)
        each_difference({ name => one_local(name) }, false, &@@diff)
      end

      # Public: Print out a list of resources defined by local configuration.
      def list
        puts local_resources.map { |name, resource| name }.join(" ")
      end

      # Public: Sync the local configuration with the configuration in AWS. Will
      # not delete resources that are not locally configured; also will not remove
      # inline policies that are not locally configured.
      def sync
        each_difference(local_resources, true) { |name, diffs| sync_difference(name, diffs) }
      end

      # Public: Sync the local configuration for one resource with AWS
      #
      # name - the name of the resource to sync
      def sync_one(name)
        each_difference({ name => one_local(name) }, false) { |name, diffs| sync_difference(name, diffs) }
      end

      # Public: Migrate AWS IAMs to Cumulus configuration.
      def migrate
        assets = "#{@migration_root}/#{@migration_dir}"
        policies_dir = "#{@migration_root}/policies"
        statics_dir = "#{policies_dir}/static"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(assets)
          Dir.mkdir(assets)
        end
        if !Dir.exists?(policies_dir)
          Dir.mkdir(policies_dir)
        end
        if !Dir.exists?(statics_dir)
          Dir.mkdir(statics_dir)
        end

        # generate the configuration objects. This MUST be done separate from
        # writing to file, because the unifier will change the configuration objects
        # as it finds ways to unify configured attributes.
        policy_unifier = PolicyUnifier.new(statics_dir)
        configs = aws_resources.map do |resource|
          puts "Processing #{@type} #{resource.name}..."
          config = empty_config
          config.name = resource.name

          config.attached_policies = resource.attached_policies.map { |p| p.arn }

          resource.policies.each do |policy|
            statements = JSON.parse(URI.decode(policy.policy_document))["Statement"]
            statements.each { |statement| statement.delete("Sid") }
            policy_unifier.unify(config, statements, policy.name)
          end

          [config, resource]
        end

        migrate_additional(configs)
        configs = configs.map { |config, resource| config }

        # write the configuration to file
        puts "Writing configuration to file..."
        configs.each do |config|
          File.open("#{assets}/#{config.name}.json", 'w') { |f| f.write(config.json) }
        end

        puts "Done."
      end

      # Public: Update a resource in AWS
      #
      # resource  - the resource to update
      # diffs     - the diff objects to be used when updating the resource
      def update(resource, diffs)
        if diffs.size == 1 and diffs[0].type == Common::DiffChange::ADD
          update_policy(resource, diffs[0].local.generated_policy_name, diffs[0].local.policy)
          if !diffs[0].local.attached_policies.empty?
            update_attached(resource, diffs[0].local.attached_policies, [])
          end
        else
          diffs.each do |diff|
            case diff.type
            when IamChange::POLICY
              update_policy(resource, diff.policy_name, diff.local)
            when IamChange::ATTACHED
              update_attached(resource, diff.attached, diff.detached)
            when IamChange::ADDED_POLICY
              update_policy(resource, diff.policy_name, diff.local)
            when IamChange::UNMANAGED_POLICY
              puts Colors.unmanaged("\t#{diff.policy_name} is not managed by Cumulus")
            end
          end
        end
      end

      private

      # Internal: Loop through the differences between local configuration and AWS
      #
      # locals            - the local configurations to compare against
      # include_unmanaged - whether to include unmanaged resources in the list of
      #                     changes
      # f                 - will be passed the name of the resource and an array of
      #                     IamDiffs
      def each_difference(locals, include_unmanaged, &f)
        aws = Hash[aws_resources.map { |aws| [aws.name, aws] }]

        if include_unmanaged
          aws.each do |name, resource|
            f.call(name, [IamDiff.unmanaged(resource)]) if !locals.include?(name)
          end
        end
        locals.each do |name, resource|
          if !aws.include?(name)
            f.call(name, [IamDiff.added(resource)])
          else
            f.call(name, resource.diff(aws[name]))
          end
        end
      end

      # Internal: Sync differences
      #
      # name  - the name of the resource to sync
      # diffs - the differences between the configuration and AWS
      def sync_difference(name, diffs)
        aws = Hash[aws_resources.map { |aws| [aws.name, aws] }]
        if diffs.size > 0
          if diffs[0].type == Common::DiffChange::UNMANAGED
            puts diffs[0]
          elsif diffs[0].type == Common::DiffChange::ADD
            puts Colors.added("creating #{name}...")
            resource = create(diffs[0])
            update(resource, diffs)
          else
            puts Colors.blue("updating #{name}...")
            resource = aws[name]
            update(resource, diffs)
          end
        end
      end

      # Internal: Update the generated policy
      #
      # resource - the AWS resource to update
      # name     - the name of the policy to update
      # config   - the policy config to use when updating
      def update_policy(resource, name, config)
        puts Colors.blue("\tupdating policy #{name}...")
        policy = resource.policy(name)
        if config.empty?
          policy.delete()
        else
          policy.put({
            :policy_document => config.as_pretty_json
          })
        end
      end

      # Internal: Update the attached policies
      #
      # resource - the AWS resource to update
      # attach   - the policy arns to attach
      # detach   - the policy arns to detach
      def update_attached(resource, attach, detach)
        puts Colors.blue("\tupdating attached policies...")
        attach.each { |arn| resource.attach_policy({ :policy_arn => arn }) }
        detach.each { |arn| resource.detach_policy({ :policy_arn => arn }) }
      end

    end
  end
end
