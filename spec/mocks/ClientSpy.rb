module Cumulus
  module Test
    SpiedMethod = Struct.new(:arguments_list) do
      def num_calls
        arguments_list.size
      end

      def arguments
        arguments_list[0]
      end
    end

    class ClientSpy
      attr_reader :method_calls

      def initialize(client)
        @method_calls = {}
        metaclass = class << self; self; end
        client.methods.each do |m|
          method_name = m.to_sym
          metaclass.send(:define_method, method_name) do |*args|
            if !@method_calls.has_key? method_name
              @method_calls[method_name] = SpiedMethod.new([])
            end
            @method_calls[method_name] = SpiedMethod.new(
              @method_calls[method_name].arguments_list.push(args)
            )
            client.method(method_name).call(*args)
          end
        end
      end

      def clear_spy
        @method_calls = {}
      end

      def spied_method(name)
        @method_calls[name]
      end

    end
  end
end
