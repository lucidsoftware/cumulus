require "iam/models/IamDiff"
require "iam/models/ResourceWithPolicy"

require "json"

module Cumulus
  module IAM
    # Public: Represents a config file for a role. Will lazily load its static and
    # template policies as needed.
    class RoleConfig < ResourceWithPolicy

      attr_accessor :policy_document

      # Public: Constructor.
      #
      # name - the name of the role
      # json - the Hash containing the JSON configuration for this RoleConfig, if
      #        nil, this will be an "empty RoleConfig"
      def initialize(name = nil, json = nil)
        super(name, json)
        @policy_document = Loader.policy_document(json["policy-document"]) unless json.nil?
        @type = "role"
      end

      # override diff to check for changes in policy documents
      def diff(aws_resource)
        differences = super(aws_resource)

        aws_policy = JSON.parse(URI.unescape(aws_resource.assume_role_policy_document)).to_s

        if one_line_policy_document != aws_policy
          differences << IamDiff.new(IamChange::POLICY_DOC, aws_resource, self)
        end

        differences
      end

      def hash
        h = super()
        h["policy-document"] = @policy_document
        h
      end

      # Internal: Get the policy document as a one line string for easier comparison
      #
      # Returns the policy on one line
      def one_line_policy_document
        JSON.parse(@policy_document).to_s
      end

    end
  end
end
