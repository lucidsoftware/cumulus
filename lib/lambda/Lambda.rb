require "conf/Configuration"

require "aws-sdk-lambda"

module Cumulus
  module Lambda
    class << self
      @@client = Aws::Lambda::Client.new(Configuration.instance.client)

      # Public: Static method that will get a Lambda function from AWS by its
      # name
      #
      # name - the name of the function to get
      #
      # Returns the function
      def get_aws(name)
        functions.fetch(name)
      rescue KeyError
        puts "No Lambda function named #{name}"
        exit
      end

      # Public: Provide a mapping of functions to their names. Lazily loads
      # resources.
      #
      # Returns the functions mapped to their names
      def functions
        @functions ||= init_functions
      end

      private

      # Internal: Load the functions and map them to their names
      #
      # Returns the functions mapped to their names
      def init_functions
        Hash[@@client.list_functions.functions.map { |f| [f.function_name, f] }]
      end
    end
  end
end
