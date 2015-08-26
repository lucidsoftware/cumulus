module Cumulus
  module S3
    class WebsiteConfig
      attr_reader :enabled
      attr_reader :error
      attr_reader :index
      attr_reader :redirect

      # Public: Constructor
      #
      # json - a hash representing the JSON configuration, expects to be handed
      #        the 'website' node of S3 configuration.
      def initialize(json = nil)
        if json
          @enabled = json["enabled"] || false
          @redirect = json["redirect"]
          @index = json["index"]
          @error = json["error"]
        end
      end

      # Public: Populate this WebsiteConfig with the values in an AWS WebsiteConfiguration
      # object.
      #
      # aws - the aws object to populate from
      def populate!(aws)
        @enabled = !aws.safe_index.nil? || !aws.safe_redirection.nil?
        @index = aws.safe_index
        @error = aws.safe_error
        @redirect = aws.safe_redirection
      end

      # Public: Check WebsiteConfig equality with other objects
      #
      # other - the other object to check
      #
      # Returns whether this WebsiteConfig is equal to `other`
      def ==(other)
        if !other.is_a? WebsiteConfig or
            @enabled != other.enabled or
            @redirect != other.redirect or
            @index != other.index or
            @error != other.error
          false
        else
          true
        end
      end

      # Public: Check if this WebsiteConfig is not equal to the other object
      #
      # other - the other object to check
      #
      # Returns whether this WebsiteConfig is not equal to `other`
      def !=(other)
        !(self == other)
      end

      def to_s
        if !@enabled
          "Not enabled"
        elsif @redirect
          "Redirect all traffic to #{@redirect}"
        elsif @index
          if @error
            "Index document: #{@index}, Error document: #{@error}"
          else
            "Index document: #{@index}"
          end
        end
      end
    end
  end
end
