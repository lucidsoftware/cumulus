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

      # Public: Returns true if all of added, removed, and modified are either nil or empty
      def empty?
        (self.added.nil? or self.added.empty?) and (self.removed.nil? or self.removed.empty?) and (self.modified.nil? or self.modified.empty?)
      end
    end
  end
end