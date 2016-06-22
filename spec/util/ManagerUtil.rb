module Cumulus
  module Test
    module ManagerUtil
      @diff_strings = []
      def diff_strings
        @diff_strings = []
        each_difference(local_resources, true) { |key, diffs| @diff_strings.concat diffs }
        @diff_strings
      end
    end
  end
end
