require "common/BaseLoader"
require "conf/Configuration"
require "sqs/models/QueueConfig"

# Public: Load SQS assets
module Cumulus
  module SQS
    module Loader
      include Common::BaseLoader

      def self.queues_dir
        Configuration.instance.sqs.queues_directory
      end

      def self.policies_dir
        Configuration.instance.sqs.policies_directory
      end

      # Public: Load all the queue configurations as QueueConfig objects
      #
      # Returns an array of QueueConfig
      def self.queues
        Common::BaseLoader::resources(self.queues_dir, &QueueConfig.method(:new))
      end

      # Public: Load the specified policy as a JSON object
      #
      # Returns the JSON object for the policy
      def self.policy(policy_name)
        Common::BaseLoader::resource(policy_name, self.policies_dir) do |policy_name, policy|
          policy
        end
      end

    end
  end
end
