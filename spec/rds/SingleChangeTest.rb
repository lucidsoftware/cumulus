module Cumulus
  module Test
    module RDS
      class SingleChangeTest

        DEFAULT_AWS_INSTANCE_NAME = "cumulus-test-instance"
        attr_reader :diffs, :client

        def initialize(args)
          @local_overrides = args[:local]
          @aws_overrides = args[:aws]
        end

        def self.execute_diff(args = Hash.new)
          test = SingleChangeTest.new(args)
          test.execute_diff
          yield test.diffs
        end

        def execute_diff
          RDS::do_diff({
            local: {instances: [{name: DEFAULT_AWS_INSTANCE_NAME, value: RDS::default_instance_attributes(@local_overrides)}]},
            aws: {describe_db_instances: {db_instances: [RDS::aws_instance(DEFAULT_AWS_INSTANCE_NAME, @aws_overrides)]}},
          }) do |diffs|
            @diffs = diffs
          end
        end

        def self.execute_sync(args = Hash.new)
          test = SingleChangeTest.new(args)
          test.execute_sync
          yield test.client
        end

        def execute_sync
          RDS::client_spy
          RDS::do_sync({
            local: {instances: [{name: DEFAULT_AWS_INSTANCE_NAME, value: RDS::default_instance_attributes(@local_overrides)}]},
            aws: {describe_db_instances: {db_instances: [RDS::aws_instance(DEFAULT_AWS_INSTANCE_NAME, @aws_overrides)]}},
          }) do |client|
            @client = client
          end
        end
      end
    end
  end
end
