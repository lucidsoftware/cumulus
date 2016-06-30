require "json"

module Cumulus
  module Common
    # Public: A module that handles loading all the 4 configuration files and
    # creating objects from them.
    module BaseLoader
      # Internal: Load the resources in a directory, handling each file with the
      # function passed in.
      #
      # dir               - the directory to load resources from
      # json              - indicates if the resources are in json format
      # individual_loader - the function that loads a resource from each file name
      #
      # Returns an array of resources
      def self.resources(dir, json = true, &individual_loader)
        Dir.entries(dir)
        .reject { |f| f == "." or f == ".." or File.directory?(File.join(dir, f)) or f.end_with?(".swp") or f.end_with?("~") }
        .map { |f| resource(f, dir, json, &individual_loader) }.reject(&:nil?)
      end

      # Internal: Load the resource, passing the parsed JSON to the function passed
      # in
      #
      # file    - the name of the file to load
      # dir     - the directory the file is located in
      # json    - indicates if the resources are in json format
      # loader  - the function that will handle the read json
      def self.resource(file, dir, json = true, &loader)
        name = file.end_with?(".json") ? file.chomp(".json") : file

        begin
          contents = load_file(file, dir)
          loader.call(
            name,
            if json then JSON.parse(contents) else contents end
          )
        rescue => e
          puts "Unable to load resource #{file}: #{e}"
          nil
        end
      end

      # Internal: Load the template, apply variables, and pass the parsed JSON to
      # the function passed in
      #
      # file    - the name of the file to load
      # dir     - the directory the file is located in
      # vars    - the variables to apply to the template
      # loader  - the function that will handle the read json
      def self.template(file, dir, vars, &loader)
        template = load_file(file, dir)
        vars.each do |key, value|
          template.gsub!("{{#{key}}}", "#{value}")
        end
        json = JSON.parse(template)

        loader.call(nil, json)
      end

      # Internal: Load a file. Will check if a file exists by the name passed in, or
      # with a .json extension.
      #
      # file - the name of the file to load
      # dir  - the directory the file is located in
      #
      # Returns the contents of the file
      def self.load_file(file, dir)
        path = File.join(dir, file)
        if File.exist?(path)
          File.read(path)
        elsif File.exist?("#{path}.json")
          File.read("#{path}.json")
        else
          throw "File does not exist: #{path}"
        end
      end
    end
  end
end
