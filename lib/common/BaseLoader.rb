require "json"

# Public: A module that handles loading all the 4 configuration files and
# creating objects from them.
module BaseLoader
  # Internal: Load the resources in a directory, handling each file with the
  # function passed in.
  #
  # dir               - the directory to load resources from
  # individual_loader - the function that loads a resource from each file name
  #
  # Returns an array of resources
  def self.resources(dir, &individual_loader)
    Dir.entries(dir)
    .reject { |f| f == "." or f == ".." or File.directory?(File.join(dir, f)) }
    .map { |f| resource(f, dir, &individual_loader) }
  end

  # Internal: Load the resource, passing the parsed JSON to the function passed
  # in
  #
  # file    - the name of the file to load
  # dir     - the directory the file is located in
  # loader  - the function that will handle the read json
  def self.resource(file, dir, &loader)
    loader.call(JSON.parse(load_file(file, dir)))
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
      template.gsub!("{{#{key}}}", value)
    end
    json = JSON.parse(template)

    loader.call(json)
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
    else
      File.read("#{path}.json")
    end
  end
end
