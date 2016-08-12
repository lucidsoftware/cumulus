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
        # Action and Resource elements are sometimes strings instead of arrays of strings.
        @action = if json["Action"].is_a? Array
          json["Action"].sort
        elsif json["Action"].is_a? String
          # convert single element strings into arrays
          json["Action"] = [json["Action"]]
        else
          raise Exception.new("invalid policy statement resource")
        end
        @resource = if json["Resource"].is_a? Array
          json["Resource"].sort
        elsif json["Resource"].is_a? String
          # convert single element strings into arrays
          json["Resource"] = [json["Resource"]]
        else
          raise Exception.new("invalid policy statement resource")
        end
        @condition = json["Condition"]
      end

      # Public: Create a Hash that contains the data in this StatementConfig which
      # can be turned into JSON that matches the format for AWS IAMS.
      #
      # Returns the Hash representing this StatementConfig.
      def as_hash
        Hash[{
          "Effect" => @effect,
          "Action" => @action,
          "Resource" => @resource,
          "Condition" => @condition
        }.sort].reject { |k, v| v.nil? }
      end

    end
  end
end
