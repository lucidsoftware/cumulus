module Cumulus
  module IAM
    # Public: A class that keeps track of strings, writing them to file and unifying
    # them if they are identical. Specifically, this is use for the assume role
    # document on roles
    class AssumeRoleUnifier
      # Public: Constructor.
      #
      # dir   - the directory to write assets to
      # save  - a function that will save a value to a config. Takes the value and
      #         the config as paramters.
      def initialize(dir, &save)
        @dir = dir
        @strings = {}
        @save = save
      end

      # Public: Unify a string with any previous instances of the string
      #
      # config - the config object that the string should belong to
      # s      - the string to unify
      # name   - the name of the file this string should be saved to if needed
      def unify(config, s, name)
        if !@strings.has_key?(s)
          File.open("#{@dir}/#{name}", 'w') { |f| f.write(s) }
          @strings[s] = name
          @save.call(config, name)
        else
          @save.call(config, @strings[s])
        end
      end
    end
  end
end
