module Cumulus
  module S3
    class WebsiteConfig
      attr_reader :error
      attr_reader :index
      attr_reader :redirect

      # Public: Constructor
      #
      # json - a hash representing the JSON configuration, expects to be handed
      #        the 'website' node of S3 configuration.
      def initialize(json = nil)
        if json
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
        @index = aws.safe_index
        @error = aws.safe_error
        @redirect = aws.safe_redirection
      end

      # Public: Produce a hash that is compatible with AWS website configuration.
      #
      # Returns the website configuration in AWS format
      def to_aws
        if @index
          {
            error_document: {
              key: @error
            },
            index_document: {
              suffix: @index
            },
          }
        else
          {
            redirect_all_requests_to: {
              host_name: if @redirect then @redirect.split("://")[1] end,
              protocol: if @redirect then @redirect.split("://")[0] end
            }
          }
        end
      end

      # Public: Check WebsiteConfig equality with other objects
      #
      # other - the other object to check
      #
      # Returns whether this WebsiteConfig is equal to `other`
      def ==(other)
        if !other.is_a? WebsiteConfig or
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
        if @redirect
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
