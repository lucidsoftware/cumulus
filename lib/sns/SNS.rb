require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module SNS
    class << self
      @@client = Aws::SNS::Client.new(Configuration.instance.client)

      # Public: Static method that will get an SNS topic from AWS by its name
      #
      # name - the name of the topic to get
      #
      # Returns the Aws::SNS::Types::Topic
      def get_aws(name)
        topics.fetch(name)
      rescue KeyError
        puts "No SNS topic named #{name}"
        exit
      end

      # Public: Provide a mapping of topics to their names.
      # Lazily loads resources.
      #
      # Returns the topics mapped to their names
      def topics
        @topics ||= init_topics
      end

      private

      # Internal: Load the topics and map them to their names
      #
      # Returns the topics mapped to their names
      def init_topics
        Hash[@@client.list_topics.topics.map { |t| [t.topic_arn[(t.topic_arn.rindex(":") + 1)..-1], t.topic_arn] }]
      end
    end
  end
end
