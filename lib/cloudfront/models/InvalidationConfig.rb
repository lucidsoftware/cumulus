module Cumulus
  module CloudFront
    # Public: An object representing configuration for a CloudFront invalidation
    class InvalidationConfig
      attr_reader :distribution_id
      attr_reader :paths


      # Public: Constructor
      #
      # json - a hash containing the JSON configuration for the invalidation
      def initialize(name, json = nil)
        if !json.nil?
          @name = name
          @distribution_id = json["distribution-id"]
          @paths = json["paths"]
        end
      end

    end
  end
end
