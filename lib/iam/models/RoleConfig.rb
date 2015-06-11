require "conf/Configuration"
require "iam/loader/Loader"
require "iam/models/Diff"
require "iam/models/PolicyConfig"
require "iam/models/StatementConfig"
require "util/Colors"

require "json"
require "uri"

# Public: Represents a config file for a role. Will lazily load its static and
# template policies as needed.
class RoleConfig

  attr_reader :name
  attr_reader :path
  attr_reader :policy_document

  # Public: Constructor.
  #
  # json - the Hash containing the JSON configuration for this RoleConfig
  def initialize(json)
    @name = json["name"]
    @path = json["path"]
    @policy_document = Loader.policy_document(json["policy-document"])
    @json = json
  end

  # Public: Lazily produce the inline policy document for this RoleConfig as a
  # PolicyConfig. Includes the static policies as well as applied templates.
  #
  # Returns the policy for this RoleConfig as a PolicyConfig
  def policy
    @policy ||= init_policy
  end

  # Internal: Produce the inline policy document for this RoleConfig as a
  # PolicyConfig. Includes the static policies as well as applied templates.
  #
  # Returns the policy for this RoleConfig as a PolicyConfig
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
  # RoleConfig.
  #
  # Returns the String name
  def generated_policy_name
    "#{@name}#{Configuration.instance.policy_suffix}"
  end

  # Internal: Lazily load the static policies for this RoleConfig
  #
  # Returns an Array of static policies as StatementConfig
  def static_statements
    @static_statements ||= init_static_statements
  end
  private :static_statements

  # Internal: Load the static policies for this RoleConfig
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

  # Internal: Lazily load the template policies for this RoleConfig, applying
  # template variables
  #
  # Returns an Array of applied templates as StatementConfig objects
  def template_statements
    @template_statements ||= init_template_statements
  end
  private :template_statements

  # Internal: Load the template policies for this RoleConfig, applying template
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
  # RoleConfig.
  def inline_statements
    @json["policies"]["inlines"].map do |inline|
      StatementConfig.new(inline)
    end
  end
  private :inline_statements

  # Public: Diff this RoleConfig with the Role from AWS
  #
  # aws_role - the Aws::IAM::Role object to compare against
  #
  # Returns a Diff object containing the differences
  def diff(aws_role)
    differences = Diff.new(@name, ChangeType::REMOVE_POLICY, self)

    aws_policies = {}
    aws_role.policies.each do |policy|
      aws_policies[policy.name] = policy
    end

    # check if we've ever generated a policy for this role
    if !aws_policies.key?(generated_policy_name)
      differences.type = ChangeType::CHANGE
      differences.add_diff(
        generated_policy_name,
        Colors.added_policy("#{generated_policy_name} will be created")
      )
    end

    aws_policies.each do |name, aws_policy|
      if name != generated_policy_name
        differences.add_diff(
          name,
          Colors.unmanaged_policy("Policy is not managed by Cumulus")
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
