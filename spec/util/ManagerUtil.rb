module Cumulus
  module Test
    module ManagerUtil
      @diff_strings = []
      def diff_strings
        @diff_strings = []
        each_difference(local_resources, true) { |key, diffs| @diff_strings.concat diffs }
        @diff_strings
      end

      # Public - override 'puts' method to prevent annoying output during tests.
      def puts(msg)
      end
    end
  end
end
