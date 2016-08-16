module Cumulus
  module Test
    module RDS
      class SingleChangeTest

        DEFAULT_AWS_INSTANCE_NAME = "cumulus-test-instance"
        attr_reader :diffs

        def initialize(args)
          @local_overrides = args[:local]
          @aws_overrides = args[:aws]
        end

        def self.execute(args = Hash.new)
          test = SingleChangeTest.new(args)
          test.execute
          yield test.diffs
        end

        def execute
          RDS::do_diff({
            local: {instances: [{name: DEFAULT_AWS_INSTANCE_NAME, value: RDS::default_instance_attributes(@local_overrides)}]},
            aws: {describe_db_instances: {db_instances: [RDS::aws_instance(DEFAULT_AWS_INSTANCE_NAME, @aws_overrides)]}},
          }) do |diffs|
            @diffs = diffs
          end
        end
      end
    end
  end
end
