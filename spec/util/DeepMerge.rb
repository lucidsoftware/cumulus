module Cumulus
  module Test
    module Util
      module DeepMerge
        # Public: Do a deep merge of two hashes, overriding the values in `first`
        # with the values in `second`.
        #
        # first - the first Hash
        # seconds - the second Hash
        #
        # Returns a Hash that contains the values in `first` merged with `second`
        def self.deep_merge(first, second)
          if first.nil?
            second
          elsif second.nil?
            first
          else
            merger = Proc.new { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
            first.merge(second, &merger)
          end
        end
      end
    end
  end
end
