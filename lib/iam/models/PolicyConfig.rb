require "conf/Configuration"
require "deepsort"
require "json"

module Cumulus
  module IAM
    # Public: Represents a policy in AWS. Contains StatementConfig objects that
    # define the things this policy allows.
    class PolicyConfig

      attr_accessor :name

      # Public: Constructor. Will be created with no statements.
      def initialize
        @version = Configuration.instance.iam.policy_version
        @statements = []
      end

      # Public: Add a StatementConfig object to the statements in this PolicyConfig
      #
      # statement - the StatementConfig object to add to this PolicyConfig
      def add_statement(statement)
        @statements.push(statement)
      end

      # Public: Determine if this policy is empty. It is considered empty if there
      # are no statements.
      #
      # Returns true if empty, false if not
      def empty?
        @statements.empty?
      end

      # Public: Create a JSON string representing this PolicyConfig which can be
      # used by AWS IAMs.
      #
      # Returns the String JSON representation
      def as_json
        as_hash.to_json
      end

      # Public: Create a pretty JSON string representing this PolicyConfig which can
      # be used by AWS IAMs.
      #
      # Returns the String JSON representation (pretty printed)
      def as_pretty_json
        JSON.pretty_generate(as_hash)
      end

      # Public: Create a Hash that contains the data in this PolicyConfig which will
      # conform to the AWS IAM format when converted to JSON
      #
      # Returns a Hash representing this PolicyConfig
      def as_hash
        statements = @statements.map do |statement|
          statement.as_hash
        end

        {
          "Version" => @version,
          "Statement" => statements
        }.deep_sort
      end

    end
  end
end
