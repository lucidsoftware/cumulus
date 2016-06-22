module Cumulus
  module Test
    # Public: Wraps a composable function. Composables can be composed with other
    # Composables, such that if a and b are Composables, then
    # a.and_then(b).call(args) = b(a(args))
    class Composable
      attr_accessor :g

      def initialize(&f)
        @f = f
        @g = nil
      end

      def and_then(g)
        composed = Composable.new(&@f)
        composed.g = g
        composed
      end

      def call(*args)
        ret = @f.call(*args)
        if @g then @g.call(ret) else ret end
      end
    end
  end
end
