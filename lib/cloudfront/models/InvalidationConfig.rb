require "json"

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
        if json
          @name = name

          begin
            @distribution_id = json.fetch("distribution-id")
          rescue KeyError
            puts "Must supply 'distribution-id' in invalidation config"
            exit
          end

          begin
            @paths = json.fetch("paths")
          rescue KeyError
            puts "Must supply 'paths' in invalidation config"
            exit
          end

        end
      end

    end
  end
end
