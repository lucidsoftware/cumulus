require "conf/Configuration"
require "iam/loader/Loader"
require "iam/models/IamDiff"
require "iam/models/PolicyConfig"
require "iam/models/StatementConfig"
require "util/Colors"
require "deepsort"

require "json"

module Cumulus
  module IAM
    # Public: Represents a configuration for a resource that has attached policies.
    # Lazily loads its static and template policies as needed. Is the base class for
    # groups, roles, and users.
    #
    # Additionally, exposes a constructor that takes no parameters. This parameter
    # essentially creates an "empty resource", which can then be filled and json
    # configuration can be generated from the object. This is useful when migrating.
    class ResourceWithPolicy

      attr_accessor :attached_policies
      attr_accessor :name
      attr_reader :inlines
      attr_reader :statics
      attr_reader :type

      # Public: Constructor.
      #
      # name - the name of the resource
      # json - a hash containing JSON configuration for this resource, if nil, this
      #        resource will be an "empty resource"
      def initialize(name = nil, json = nil)
        if !json.nil?
          @name = name
          @json = json
          @attached_policies = json["policies"]["attached"]
          @statics = json["policies"]["static"]
          @templates = json["policies"]["templates"]
          @inlines = json["policies"]["inlines"]
        else
          @name = nil
          @attached_policies = []
          @statics = []
          @templates = []
          @inlines = []
        end
      end

      # Public: Generate the JSON string to turn this object back into a Cumulus
      # config file.
      #
      # Returns the JSON string.
      def json
        JSON.pretty_generate(hash)
      end

      # Public: Generate a hash that represents this config. This hash will be json
      # serializable to Cumulus config format
      #
      # Returns the hash
      def hash
        {
          "name" => @name,
          "policies" => {
            "attached" => @attached_policies,
            "inlines" => @inlines.flatten,
            "static" => @statics,
            "templates" => @templates
          }
        }
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
        @statics.map do |name|
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
        @templates.map do |template|
          Loader.template_policy(template["template"], template["vars"])
        end.flatten
      end
      private :init_template_statements

      # Internal: Load the inline policies defined in the JSON config for this
      # resource.
      def inline_statements
        @inlines.map do |inline|
          StatementConfig.new(inline)
        end
      end
      private :inline_statements

      # Public: Diff this resource with the resource from AWS
      #
      # aws_resource - the Aws::IAM::* resource to compare against
      #
      # Returns an array of IamDiff objects representing the differences
      def diff(aws_resource)
        diffs = []

        aws_policies = Hash[aws_resource.policies.map do |policy|
          # Sort the statments before diffing to prevent false conflicts
          [policy.name, JSON.parse(URI.unescape(policy.policy_document)).deep_sort]
        end]
        p = policy
        p.name = generated_policy_name

        # check if we've ever generated a policy for this resource
        if !aws_policies.key?(generated_policy_name) and !policy.empty?
          diffs << IamDiff.added_policy(generated_policy_name, p)
        end

        # loop through all the policies and look for changes
        aws_policies.each do |name, aws_policy|
          if name != generated_policy_name
            diffs << IamDiff.unmanaged_policy(name)
          else
            aws_statements = aws_policy["Statement"]
            local_statements = p.as_hash["Statement"]
            if aws_statements != local_statements
              diff = IamDiff.new(IamChange::POLICY, aws_statements, p)
              diff.policy_name = generated_policy_name
              diffs << diff
            end
          end
        end

        # look for changes in managed policies
        aws_arns = aws_resource.attached_policies.map { |a| a.arn }
        new_policies = @attached_policies.select { |local| !aws_arns.include?(local) }
        removed_policies = aws_arns.select { |aws| !@attached_policies.include?(aws) }
        if !new_policies.empty? or !removed_policies.empty?
          diffs << IamDiff.attached(new_policies, removed_policies)
        end

        diffs
      end

    end
  end
end
