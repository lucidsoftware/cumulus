require "conf/Configuration"
require "util/Colors"

require "aws-sdk-sqs"

module Cumulus
  module SQS
    class << self
      @@client = Aws::SQS::Client.new(Configuration.instance.client)

      # Public
      # Returns the AWS client used in the module
      def client
        @@client
      end

      # Public: Static method that will get the ARN of a Queue
      #
      # name - the name of the queue to get
      #
      # Returns the String ARN
      def get_arn(queue_name)
        queue_arns.fetch(queue_name)
      rescue KeyError
        puts Colors.red("No SQS queue named #{queue_name}")
        exit 1
      end

      # Public: Returns a mapping of queue name to ARN
      def queue_arns
        @queue_arns ||= Hash[queue_attributes.map { |name, attrs| [name, attrs["QueueArn"]] }]
      end

      # Public: Return the policy of a queue as a Hash
      def queue_policy(queue_name)
        JSON.parse(URI.decode(queue_attributes[queue_name]["Policy"])) rescue nil
      end

      # Public: Return a mapping of queue name to url
      def queue_urls
        @queue_urls ||= init_urls
      end

      # Public: Return a mapping of queue name to attributes
      def queue_attributes
        @queue_attributes ||= Hash[queue_urls.map { |name, url| [name, init_attributes(url)] }]
      end

      private

      # Internal: Returns a Hash of attribute names to values
      def init_attributes(queue_url)
        @@client.get_queue_attributes({
          queue_url: queue_url,
          attribute_names: ["All"]
        }).attributes
      rescue Aws::SQS::Errors::NonExistentQueue
        puts "Queue #{queue_url} has been deleted. Please wait a few seconds until AWS updates the list of queues"
        exit 1
      end

      # Internal: Map queue names to their urls.
      def init_urls
        Hash[@@client.list_queues.queue_urls.map { |u| [u[(u.rindex("/") + 1)..-1], u] }]
      end
    end
  end
end
