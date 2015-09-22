module Cumulus
  module Common
    ListChange = Struct.new(:added, :removed, :modified) do
      # Public: Creates a ListChange from aws and local arrays with simple types
      # where the ListChange only has added and removed
      def self.simple_list_diff(aws, local)
        added = local - aws
        removed = aws - local

        if !added.empty? or !removed.empty?
          ListChange.new(added, removed, nil)
        end
      end
    end
  end
end