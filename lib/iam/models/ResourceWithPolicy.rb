require "conf/Configuration"
require "iam/loader/Loader"
require "iam/models/Diff"
require "iam/models/PolicyConfig"
require "iam/models/StatementConfig"
require "util/Colors"

# Public: Represents a configuration for a resource that has attached policies.
# Lazily loads its static and template policies as needed. Is the base class for
# groups, roles, and users.
class ResourceWithPolicy

  attr_reader :name
  attr_reader :type

  # Public: Constructor.
  #
  # json - a hash containing JSON configuration for this resource
  def initialize(json)
    @name = json["name"]
    @json = json
  end

  # Public: Lazily produce the inline policy document for this resource as a
  # PolicyConfig. Includes the static and inline policies as well as applied
  # templates.
  #
  # Returns the policy for this resource as a PolicyConfig
  def policy
    @policy ||= init_policy
  end

  # Internal: Produce the inline policy document for this resource as a
  # PolicyConfig. Includes the static and inline policies as well as applied
  # templates.
  #
  # Returns the policy for this resource as a PolicyConfig
  def init_policy
    policy = PolicyConfig.new
    static_statements.each do |statement|
      policy.add_statement(statement)
    end
    template_statements.each do |statement|
      policy.add_statement(statement)
    end
    inline_statements.each do |statement|
      policy.add_statement(statement)
    end
    policy
  end
  private :init_policy

  # Public: Produce the name for the policy that will be generated for this
  # resource.
  #
  # Returns the String name
  def generated_policy_name
    policy_prefix = Configuration.instance.iam.policy_prefix
    policy_suffix = Configuration.instance.iam.policy_suffix
    "#{policy_prefix}#{@name}#{policy_suffix}"
  end

  # Internal: Lazily load the static policies for this resource
  #
  # Returns an Array of static policies as StatementConfig
  def static_statements
    @static_statements ||= init_static_statements
  end
  private :static_statements

  # Internal: Load the static policies for this resource
  #
  # Returns an Array of static policies as StatementConfig
  def init_static_statements
    statements = []
    @json["policies"]["static"].map do |name|
      statements << Loader.static_policy(name)
    end
    statements.flatten!
    statements
  end
  private :init_static_statements

  # Internal: Lazily load the template policies for this resource, applying
  # template variables
  #
  # Returns an Array of applied templates as StatementConfig objects
  def template_statements
    @template_statements ||= init_template_statements
  end
  private :template_statements

  # Internal: Load the template policies for this resource, applying template
  # variables
  #
  # Returns an Array of applied templates as StatementConfig objects
  def init_template_statements
    @json["policies"]["templates"].map do |name, variables|
      Loader.template_policy(name, variables)
    end
  end
  private :init_template_statements

  # Internal: Load the inline policies defined in the JSON config for this
  # resource.
  def inline_statements
    @json["policies"]["inlines"].map do |inline|
      StatementConfig.new(inline)
    end
  end
  private :inline_statements

  # Public: Diff this resource with the resource from AWS
  #
  # aws_resource - the Aws::IAM::* resource to compare against
  #
  # Returns a Diff object containing the differences
  def diff(aws_resource)
    differences = Diff.new(@name, ChangeType::REMOVE_POLICY, @type, self)

    aws_policies = {}
    aws_resource.policies.each do |policy|
      aws_policies[policy.name] = policy
    end

    # check if we've ever generated a policy for this resource
    if !aws_policies.key?(generated_policy_name)
      differences.type = ChangeType::CHANGE
      differences.add_diff(
        generated_policy_name,
        Colors.added("#{generated_policy_name} will be created")
      )
    end

    aws_policies.each do |name, aws_policy|
      if name != generated_policy_name
        differences.add_diff(
          name,
          Colors.unmanaged("Policy is not managed by Cumulus")
        )
      else
        aws_statements = JSON.parse(URI.unescape(aws_policy.policy_document))["Statement"]
        local_statements = policy.as_hash["Statement"]

        if aws_statements != local_statements
          differences.type = ChangeType::CHANGE
          aws_statements.each do |aws|
            if !local_statements.include?(aws)
              differences.add_diff(name, "AWS:\t#{Colors.aws_changes(aws.to_json)}")
            end
          end

          local_statements.each do |local|
            if !aws_statements.include?(local)
              differences.add_diff(name, "Local:\t#{Colors.local_changes(local.to_json)}")
            end
          end
        end
      end
    end

    differences
  end

end
