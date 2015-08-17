module Cumulus
  module IAM
    # Public: A class that keeps track of policy statements, determining when to put
    # a policy into the inline definition of the resource, or to create a static
    # policy that can apply to multiple resources. It does this by keeping track of
    # policies that it's seen before, and putting everything into inlines. When it
    # sees something for the second time, it will remove the policy from the first
    # resource's inlines, and creates a static policy definition.
    class PolicyUnifier

      # the following inner classes are used to keep track of whether we've seen
      # a policy before. `SingleInstance` and `MultipleInstances` both extend
      # `Instance`, as both of them have a `name` attribute.
      class Instance
        attr_reader :name
        def initialize(name)
          @name = name
        end
      end

      class SingleInstance < Instance
        attr_reader :config
        def initialize(config, name)
          super(name)
          @config = config
        end
      end

      class MultipleInstances < Instance
      end

      # Public: Constructor
      #
      # dir - the directory to write static policies to
      def initialize(dir)
        @dir = dir
        @policies = {}
      end

      # Public: Unify a particular policy for a configuration object. If `policy`
      # has not been encountered before, it will be put into the config's inlines,
      # but if it has, it will be written to static and added to the static array
      # of the configuration. Will also go back and fix the inlines for the first
      # time `policy` was encountered.
      #
      # config - the config object to change
      # policy - the policy to unify
      # name   - the name of the file to write, if needed
      def unify(config, policy, name)
        # if we haven't seen the policy before, add it to the inlines
        if !@policies.has_key?(policy)
          @policies[policy] = SingleInstance.new(config, name)
          config.inlines << policy
        else
          case @policies[policy]
          # if we've only seen the policy once before, write it to file and fix the
          # previous configuration that had the policy
          when SingleInstance
            single = @policies[policy]

            # write to file, checking for naming conflicts
            file = "#{@dir}/#{single.name}"
            contents = JSON.pretty_generate(policy)
            if File.exists?(file)
              original_contents = File.read(file)
              if original_contents != contents
                file = "#{file}-#{single.config.name}"
              end
            end
            File.open(file, 'w') { |f| f.write(contents) }
            file = file[(file.rindex("/") + 1)..-1]

            # update the config objects
            single.config.inlines.delete(policy)
            single.config.statics << file
            config.statics << file
            @policies[policy] = MultipleInstances.new(file)

          # if the policy has already been written to file, we just use the static
          # in the configuration
          when MultipleInstances
            multiple = @policies[policy]
            config.statics << multiple.name
          end
        end
      end

    end
  end
end
