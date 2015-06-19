require "iam/migration/PolicyUnifier"
require "iam/models/Diff"
require "util/Colors"

require 'uri'

# Internal: Represents the manager of a type of IamResource. Base class for
# groups, roles, and users.
class IamResource
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
    puts differences.join("\n")
  end

  # Public: Print out the diff between local configuration and AWS for one
  # resource
  #
  # name - the name of the resource to diff
  def diff_one(name)
    puts one_difference(name)
  end

  # Public: Print out a list of resources defined by local configuration.
  def list
    names = local_resources.map do |name, resource|
      name
    end
    puts names.join(" ")
  end

  # Public: Sync the local configuration with the configuration in AWS. Will
  # not delete resources that are not locally configured; also will not remove
  # inline policies that are not locally configured.
  def sync
    sync_changes(differences)
  end

  # Public: Sync the local configuration for one resource with AWS
  #
  # name - the name of the resource to sync
  def sync_one(name)
    sync_changes(one_difference(name))
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
      File.open("#{assets}/#{config.name}", 'w') { |f| f.write(config.json) }
    end

    puts "Done."
  end

  # Public: Update a resource in AWS
  #
  # resource  - the resource to update
  # diff    - the diff object to be used when updating the resource
  def update(resource, diff)
    if !diff.config.policy.empty?
      policy = resource.policy(diff.config.generated_policy_name)
      policy.put({
        :policy_document => diff.config.policy.as_pretty_json
      })
    else
      puts Colors.red("Policy is empty. Not uploaded")
    end

    if !diff.attached_policies.empty?
      diff.attached_policies.each do |arn|
        resource.attach_policy({ :policy_arn => arn })
      end
    end
    if !diff.detached_policies.empty?
      diff.detached_policies.each do |arn|
        resource.detach_policy({ :policy_arn => arn })
      end
    end
  end

  # Internal: Sync all the changes passed into the function to AWS
  #
  # diffs - the differences to sync
  def sync_changes(diffs)
    aws = {}
    aws_resources.each do |resource|
      aws[resource.name] = resource
    end

    diffs.each do |difference|
      if difference.type == ChangeType::REMOVE
        puts difference
      elsif difference.type == ChangeType::ADD
        puts Colors.blue("creating #{difference.name}")
        resource = create(difference)
        update(resource, difference)
      elsif difference.type == ChangeType::REMOVE_POLICY
        puts Colors.red("#{difference.name} has policies not managed by Cumulus")
      else
        puts Colors.blue("updating #{difference.name}...")
        aws_resource = aws[difference.name]
        update(aws_resource, difference)
      end
    end
  end
  private :sync_changes

  # Internal: Get all the differences between the local configuration and the
  # IAMS in AWS
  #
  # Returns and Array of Diff objects that represent the differences
  def differences
    calculate_differences(local_resources, true)
  end
  private :differences

  # Internal: Find the differences between local and AWS configuration for one
  # resource.
  #
  # name - the name of the resource to check
  #
  # Returns the differences
  def one_difference(name)
    local = {
      name => one_local(name)
    }

    calculate_differences(local, false)
  end
  private :one_difference

  # Internal: Find the differences between the local and AWS configurations.
  #
  # local               - the local resources to check against
  # include_non_managed - whether to show the resources in AWS that aren't
  #                       managed by Cumulus
  #
  # Returns an array of differences
  def calculate_differences(local, include_non_managed)
    aws = {}
    aws_resources.each do |resource|
      aws[resource.name] = resource
    end

    differences = []
    if include_non_managed
      aws.each do |name, resource|
        if !local.key?(name)
          differences << Diff.new(name, ChangeType::REMOVE, nil)
        end
      end
    end

    local.each do |name, resource|
      if !aws.key?(name)
        differences << Diff.new(name, ChangeType::ADD, resource)
      end
    end

    aws.each do |name, resource|
      if local.key?(name)
        d = local[name].diff(resource)
        if d.different?
          differences << d
        end
      end
    end

    differences
  end
  private :calculate_differences
end
