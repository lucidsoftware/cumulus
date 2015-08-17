module Cumulus
  module IAM
    # Public: Represents a policy config file.
    class StatementConfig

      attr_reader :effect
      attr_reader :action
      attr_reader :resource

      # Public: Constructor.
      #
      # json - the Hash containing the JSON configuration for this StatementConfig
      def initialize(json)
        @effect = json["Effect"]
        @action = json["Action"]
        @resource = json["Resource"]
        @condition = json["Condition"]
      end

      # Public: Create a Hash that contains the data in this StatementConfig which
      # can be turned into JSON that matches the format for AWS IAMS.
      #
      # Returns the Hash representing this StatementConfig.
      def as_hash
        {
          "Effect" => @effect,
          "Action" => @action,
          "Resource" => @resource,
          "Condition" => @condition
        }.reject { |k, v| v.nil? }
      end

    end
  end
end
