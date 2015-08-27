require "conf/Configuration"

require "aws-sdk"

module Cumulus
  module SQS
    class << self
      @@client = Aws::SQS::Client.new(region: Configuration.instance.region)

      # Public: Static method that will get the ARN of a Queue
      #
      # name - the name of the queue to get
      #
      # Returns the String ARN
      def get_arn(name)
        @@client.get_queue_attributes({
          queue_url: urls.fetch(name),
          attribute_names: ["QueueArn"]
        }).attributes["QueueArn"]
      rescue KeyError
        puts "No SQS queue named #{name}"
        exit
      end

      private

      # Internal: Return a mapping of queue name to url. Loads lazily.
      def urls
        @urls ||= init_urls
      end

      # Internal: Map queue names to their urls.
      def init_urls
        Hash[@@client.list_queues.queue_urls.map { |u| [u[(u.rindex("/") + 1)..-1], u] }]
      end
    end
  end
end
