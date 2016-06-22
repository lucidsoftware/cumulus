module Cumulus
  module Test
    module MockedLoader
      # keep a map of the paths we've stubbed to the arrays of json they
      # should return
      @@stubbed_directories = {}

      # keep a map of the files we've stubbed to the contents of those
      # files
      @@stubbed_files = {}

      def self.included(base)
        base.instance_eval do
          def stub_directory(path, json)
            @@stubbed_directories[path] = json
          end

          def stub_file(path, json)
            @@stubbed_files[path] = json
          end

          def resources(dir, json = true, &individual_loader)
            @@stubbed_directories[dir].map do |json|
              individual_loader.call(json[:name], json[:value])
            end
          end

          def resource(file, dir, json = true, &loader)
            path = File.join(dir, file)
            contents = @@stubbed_files[path]
            loader.call(path, if json then JSON.parse(contents) else contents end)
          end
        end
      end
    end
  end
end
