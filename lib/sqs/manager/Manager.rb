require "common/manager/Manager"
require "conf/Configuration"
require "util/Colors"
require "sqs/models/QueueConfig"
require "sqs/models/QueueDiff"
require "sqs/SQS"

require "aws-sdk"
require "json"

module Cumulus
  module SQS
    class Manager < Common::Manager

      def initialize
        super()
        @create_asset = true
        @client = Aws::SQS::Client.new(region: Configuration.instance.region, profile: Configuration.instance.profile)
      end

      def resource_name
        "Queue"
      end

      def local_resources
        @local_resources ||= Hash[Loader.queues.map { |local| [local.name, local] }]
      end

      def aws_resources
        @aws_resources ||= Hash[SQS::queue_attributes.map { |name, attrs| [name, QueueConfig.new(name).populate!(attrs) ] }]
      end

      def unmanaged_diff(aws)
        QueueDiff.unmanaged(aws)
      end

      def added_diff(local)
        QueueDiff.added(local)
      end

      def diff_resource(local, aws)
        local.diff(aws)
      end

      def urls
        local_resources.keys.sort.each do |name|
          url = SQS::queue_urls[name] || "does not exist"
          puts "#{name} => #{url}"
        end
      end

      def update(local, diffs)
        @client.set_queue_attributes({
          queue_url: SQS::queue_urls[local.name],
          attributes: {
            "DelaySeconds" => if diffs.any? { |d| d.type == QueueChange::DELAY } then local.delay end,
            "MaximumMessageSize" => if diffs.any? { |d| d.type == QueueChange::MESSAGE_SIZE } then local.max_message_size end,
            "MessageRetentionPeriod" => if diffs.any? { |d| d.type == QueueChange::MESSAGE_RETENTION } then local.message_retention end,
            "Policy" => if diffs.any? { |d| d.type == QueueChange::POLICY }
              if local.policy then JSON.generate(Loader.policy(local.policy)) else "" end
            end,
            "ReceiveMessageWaitTimeSeconds" => if diffs.any? { |d| d.type == QueueChange::RECEIVE_WAIT } then local.receive_wait_time end,
            "VisibilityTimeout" => if diffs.any? { |d| d.type == QueueChange::VISIBILITY } then local.visibility_timeout end,
            "RedrivePolicy" => if diffs.any? { |d| d.type == QueueChange::DEAD }
              if local.dead_letter then JSON.generate(local.dead_letter.to_aws) else "" end
            end
          }.reject { |k, v| v.nil? }
        })
      end

      def create(local)
        url = @client.create_queue({
          queue_name: local.name,
          attributes: {
            "DelaySeconds" => local.delay,
            "MaximumMessageSize" => local.max_message_size,
            "MessageRetentionPeriod" => local.message_retention,
            "Policy" => if local.policy then JSON.generate(Loader.policy(local.policy)) end,
            "ReceiveMessageWaitTimeSeconds" => local.receive_wait_time,
            "VisibilityTimeout" => local.visibility_timeout,
            "RedrivePolicy" => if local.dead_letter then JSON.generate(local.dead_letter.to_aws) end
          }.reject { |k, v| v.nil? }
        }).queue_url
        puts Colors.blue("Queue #{local.name} was created with url #{url}")
      end

      # Public: Migrates the existing AWS config to Cumulus
      def migrate
        # Create the directories
        sqs_dir = "#{@migration_root}/sqs"
        policies_dir = "#{sqs_dir}/policies"
        queues_dir = "#{sqs_dir}/queues"

        if !Dir.exists?(@migration_root)
          Dir.mkdir(@migration_root)
        end
        if !Dir.exists?(sqs_dir)
          Dir.mkdir(sqs_dir)
        end
        if !Dir.exists?(policies_dir)
          Dir.mkdir(policies_dir)
        end
        if !Dir.exists?(queues_dir)
          Dir.mkdir(queues_dir)
        end

        puts Colors.blue("Migrating queues to #{queues_dir}")
        aws_resources.each do |name, config|
          puts Colors.blue("Migrating queue #{name}")

          # If there is a policy, then save it to the policies dir with the name of the queue
          queue_policy = SQS::queue_policy(name)
          if queue_policy
            policy_json = JSON.pretty_generate(queue_policy)
            policy_file = "#{policies_dir}/#{name}.json"
            puts "Migrating policy to #{policy_file}"
            File.open("#{policy_file}", "w") { |f| f.write(policy_json) }
          end

          json = JSON.pretty_generate(config.to_hash)
          File.open("#{queues_dir}/#{name}.json", "w") { |f| f.write(json) }
        end

      end

    end
  end
end
